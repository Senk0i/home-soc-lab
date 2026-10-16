<?php
/*
 * pfSense-A (edge firewall) baseline: routes, NAT, firewall rules.
 * Interfaces: wan=em0 192.168.1.1/24 (attacker), lan=em1 192.168.14.1/24 (DMZ),
 *             opt1=em2 192.168.20.1/24 (transit to pfSense-B)
 *
 * Run on the firewall shell:  php -f /root/pfsense-a-baseline.php
 * Replaces ALL existing filter rules with the baseline below.
 */
require_once('globals.inc');
require_once('config.inc');
require_once('functions.inc');
require_once('filter.inc');
require_once('shaper.inc');
require_once('gwlb.inc');
require_once('interfaces.inc');
require_once('util.inc');

global $config;

$tracker = 1767100000;

function add_rule($if, $type, $proto, $src, $dst, $dport, $descr) {
    global $config, $tracker;
    $tracker++;
    $r = array(
        'type' => $type,
        'interface' => $if,
        'ipprotocol' => 'inet',
        'tracker' => (string)$tracker,
        'statetype' => 'keep state',
        'descr' => $descr,
        'source' => ($src == 'any') ? array('any' => '') : array('address' => $src),
        'destination' => ($dst == 'any') ? array('any' => '') : array('address' => $dst),
    );
    if ($proto != '') { $r['protocol'] = $proto; }
    if ($dport != '') { $r['destination']['port'] = $dport; }
    $config['filter']['rule'][] = $r;
}

if (!is_array($config['filter'])) { $config['filter'] = array(); }
$config['filter']['rule'] = array();

/* WAN = attacker network: only the DMZ is reachable */
add_rule('wan', 'pass', 'icmp', '192.168.1.0/24', '192.168.1.1', '', 'Attacker ping firewall');
add_rule('wan', 'pass', '', '192.168.1.0/24', '192.168.14.0/24', '', 'Attacker to DMZ');

/* LAN = DMZ: agents may reach Wazuh, nothing else inward */
add_rule('lan', 'pass', 'tcp/udp', '192.168.14.0/24', '192.168.11.10', '1514-1515', 'DMZ agents to Wazuh');
add_rule('lan', 'block', '', '192.168.14.0/24', '192.168.11.0/24', '', 'Block DMZ to SOC');
add_rule('lan', 'block', '', '192.168.14.0/24', '192.168.30.0/24', '', 'Block DMZ to AD');
add_rule('lan', 'block', '', '192.168.14.0/24', '192.168.20.0/24', '', 'Block DMZ to transit');
add_rule('lan', 'pass', '', '192.168.14.0/24', 'any', '', 'DMZ to attacker net / other');

/* OPT1 = transit: SOC and AD may reach the DMZ; pfSense-B may ping */
add_rule('opt1', 'pass', 'icmp', '192.168.20.2', '192.168.20.1', '', 'Ping from pfSense-B');
add_rule('opt1', 'pass', '', '192.168.11.0/24', '192.168.14.0/24', '', 'SOC to DMZ');
add_rule('opt1', 'pass', '', '192.168.30.0/24', '192.168.14.0/24', '', 'AD to DMZ');

/* Empty XML sections load as strings; make them arrays before use */
foreach (array('filter', 'gateways', 'staticroutes', 'nat') as $section) {
    if (!is_array($config[$section])) { $config[$section] = array(); }
}
if (!is_array($config['nat']['outbound'])) { $config['nat']['outbound'] = array(); }

/* Static gateway and routes to the networks behind pfSense-B */
$config['gateways']['gateway_item'] = array(array(
    'interface' => 'opt1', 'gateway' => '192.168.20.2', 'name' => 'TRANSIT_GW',
    'weight' => '1', 'ipprotocol' => 'inet', 'descr' => 'pfSense-B',
));
$config['staticroutes']['route'] = array(
    array('network' => '192.168.11.0/24', 'gateway' => 'TRANSIT_GW', 'descr' => 'SOC via pfSense-B'),
    array('network' => '192.168.30.0/24', 'gateway' => 'TRANSIT_GW', 'descr' => 'AD via pfSense-B'),
);

/* Routed (no NAT) lab; the WAN side is a private lab network */
$config['nat']['outbound']['mode'] = 'disabled';
unset($config['interfaces']['wan']['blockpriv']);
unset($config['interfaces']['wan']['blockbogons']);

write_config('Phase 1 baseline: routes, NAT off, firewall rules');
filter_configure();
system_routing_configure();
setup_gateways_monitor();
echo "pfSense-A baseline applied: " . count($config['filter']['rule']) . " rules, "
   . count($config['staticroutes']['route']) . " routes\n";
