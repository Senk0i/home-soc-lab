<?php
/*
 * pfSense-B (inner firewall) baseline: NAT, firewall rules.
 * Interfaces: wan=em0 192.168.20.2/24 (transit, gateway 192.168.20.1),
 *             lan=em1 192.168.11.1/24 (SOC), opt1=em2 192.168.30.1/24 (AD)
 *
 * Run on the firewall shell:  php -f /root/pfsense-b-baseline.php
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

$tracker = 1767200000;

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

/* WAN = transit: only DMZ agent logs to Wazuh may come inward */
add_rule('wan', 'pass', 'icmp', '192.168.20.1', '192.168.20.2', '', 'Ping from pfSense-A');
add_rule('wan', 'pass', 'tcp/udp', '192.168.14.0/24', '192.168.11.10', '1514-1515', 'DMZ agents to Wazuh');

/* LAN = SOC: analysts and tools may reach everything */
add_rule('lan', 'pass', '', '192.168.11.0/24', 'any', '', 'SOC to anywhere');

/* OPT1 = AD: logs to the SOC, access to the DMZ */
add_rule('opt1', 'pass', '', '192.168.30.0/24', '192.168.11.0/24', '', 'AD to SOC');
add_rule('opt1', 'pass', '', '192.168.30.0/24', '192.168.14.0/24', '', 'AD to DMZ');

/* Routed (no NAT) lab; the WAN side is a private lab network */
if (!is_array($config['nat'])) { $config['nat'] = array(); }
if (!is_array($config['nat']['outbound'])) { $config['nat']['outbound'] = array(); }
$config['nat']['outbound']['mode'] = 'disabled';
unset($config['interfaces']['wan']['blockpriv']);
unset($config['interfaces']['wan']['blockbogons']);

write_config('Phase 1 baseline: NAT off, firewall rules');
filter_configure();
system_routing_configure();
setup_gateways_monitor();
echo "pfSense-B baseline applied: " . count($config['filter']['rule']) . " rules\n";
