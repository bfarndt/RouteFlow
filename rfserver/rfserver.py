#!/usr/bin/env python
#-*- coding:utf-8 -*-

import sys

import rflib.ipc.IPC as IPC
import rflib.ipc.MongoIPC as MongoIPC
from rflib.ipc.RFProtocol import *
from rflib.ipc.rfprotocolfactory import RFProtocolFactory
from rflib.defs import *

from rftable import *

# Register actions
REGISTER_IDLE = 0
REGISTER_ASSOCIATED = 1

class RFServer(RFProtocolFactory, IPC.IPCMessageProcessor):
    def __init__(self, configfile):
        self.rftable = RFTable()
        self.config = RFConfig(configfile)
        self.configured_rfvs = False

        self.ipc = MongoIPC.MongoIPCMessageService(MONGO_ADDRESS, MONGO_DB_NAME, RFSERVER_ID)
        self.ipc.listen(RFCLIENT_RFSERVER_CHANNEL, self, self, False)
        self.ipc.listen(RFSERVER_RFPROXY_CHANNEL, self, self, True)

    def process(self, from_, to, channel, msg):
        type_ = msg.get_type()
        if type_ == PORT_REGISTER:
            self.register_vm_port(msg.get_vm_id(), msg.get_vm_port())
        elif type_ == ROUTE_INFO:
            ri = RFServer.RouteInformation()
            ri.from_message(msg)
            self.register_route_information(ri)
        elif type_ == DATAPATH_PORT_REGISTER:
            self.register_dp_port(msg.get_dp_id(), msg.get_dp_port());
        elif type_ == DATAPATH_DOWN:
            self.set_dp_down(msg.get_dp_id())
        elif type_ == VIRTUAL_PLANE_MAP:
            self.map_port(msg.get_vm_id(), msg.get_vm_port(),
                          msg.get_vs_id(), msg.get_vs_port())
        else:
            return False
        return True

    # Port register methods
    def register_vm_port(self, vm_id, vm_port):
        action = None
        config_entry = self.config.get_config_for_vm_port(vm_id, vm_port)
        if config_entry is None:
            # Register idle VM awaiting for configuration
            action = REGISTER_IDLE
        else:
            entry = self.rftable.get_entry_by_dp_port(config_entry.dp_id, config_entry.dp_port)
            # If there's no entry, we have no DP, register VM as idle
            if entry is None:
                action = REGISTER_IDLE
            # If there's an idle DP entry matching configuration, associate
            elif entry.get_status() == RFENTRY_IDLE_DP_PORT:
                action = REGISTER_ASSOCIATED

        # Apply action
        if action == REGISTER_IDLE:
            self.rftable.set_entry(RFEntry(vm_id=vm_id, vm_port=vm_port))
        elif action == REGISTER_ASSOCIATED:
            entry.associate(vm_id, vm_port)
            self.rftable.set_entry(entry)
            self.config_vm_port(vm_id, vm_port)

    def config_vm_port(self, vm_id, vm_port):
        self.ipc.send(RFCLIENT_RFSERVER_CHANNEL, str(vm_id),
                      PortConfig(vm_id=vm_id, vm_port=vm_port, operation_id=0))
        print "Sent port config to vm id=%s" % str(vm_id)

    # RouteInfo methods
    class RouteInformation:
        def __init__(self, vm_id=None,
                           vm_port=None,
                           address=None,
                           netmask=None,
                           dst_port=None,
                           src_hwaddress=None,
                           dst_hwaddress=None,
                           is_removal=None):
            self.vm_id = vm_id
            self.vm_port = vm_port
            self.address = address
            self.netmask = netmask
            self.dst_port = dst_port
            self.src_hwaddress = src_hwaddress
            self.dst_hwaddress = dst_hwaddress
            self.is_removal = is_removal

        def from_message(self, msg):
            self.vm_id = msg.get_vm_id()
            self.vm_port = msg.get_vm_port()
            self.address = msg.get_address()
            self.netmask = msg.get_netmask()
            self.dst_port = msg.get_dst_port()
            self.src_hwaddress = msg.get_src_hwaddress()
            self.dst_hwaddress = msg.get_dst_hwaddress()
            self.is_removal = msg.get_is_removal()

    def register_route_information(self, ri):
        entry = self.rftable.get_entry_by_vm_port(ri.vm_id, ri.vm_port)
        # If the entry is not active, don't try to update
        if entry.get_status() != RFENTRY_ACTIVE:
            return

        msg = FlowMod(dp_id=entry.dp_id,
            address=ri.address,
            netmask=ri.netmask,
            dst_port=ri.dst_port,
            src_hwaddress=ri.src_hwaddress,
            dst_hwaddress=ri.dst_hwaddress,
            is_removal=ri.is_removal)
        self.ipc.send(RFSERVER_RFPROXY_CHANNEL, RFPROXY_ID, msg);

    # DatapathPortRegister methods
    def register_dp_port(self, dp_id, dp_port):
        stop = self.config_dp(dp_id)
        if stop:
            return

        # The logic down here is pretty much the same as register_vm_port
        action = None
        config_entry = self.config.get_config_for_dp_port(dp_id, dp_port)
        if config_entry is None:
            # Register idle DP awaiting for configuration
            action = REGISTER_IDLE
        else:
            entry = self.rftable.get_entry_by_vm_port(config_entry.vm_id, config_entry.vm_port)
            # If there's no entry, we have no DP, register VM as idle
            if entry is None:
                action = REGISTER_IDLE
            # If there's an idle VM entry matching configuration, associate
            elif entry.get_status() == RFENTRY_IDLE_VM_PORT:
                action = REGISTER_ASSOCIATED

        # Apply action
        if action == REGISTER_IDLE:
            self.rftable.set_entry(RFEntry(dp_id=dp_id, dp_port=dp_port))
        elif action == REGISTER_ASSOCIATED:
            entry.associate(dp_id, dp_port)
            self.rftable.set_entry(entry)
            self.config_vm_port(entry.vm_id, entry.vm_port)

    def send_datapath_config_message(self, dp_id, operation_id):
        self.ipc.send(RFSERVER_RFPROXY_CHANNEL, RFPROXY_ID,
                      DatapathConfig(dp_id=dp_id, operation_id=operation_id))

    def config_dp(self, dp_id):
        if dp_id == RFVS_DPID and not self.configured_rfvs:
            # If rfvs is coming up and we haven't configured it yet, do it
            self.configured_rfvs = True
            self.send_datapath_config_message(dp_id, DC_ALL)
        elif self.rftable.is_dp_registered(dp_id):
            # Configure a normal switch. Clear the tables and install default flows.
            self.send_datapath_config_message(dp_id, DC_CLEAR_FLOW_TABLE);
            # TODO: enforce order: clear should always be executed first
            self.send_datapath_config_message(dp_id, DC_OSPF);
            self.send_datapath_config_message(dp_id, DC_BGP);
            self.send_datapath_config_message(dp_id, DC_RIPV2);
            self.send_datapath_config_message(dp_id, DC_ARP);
            self.send_datapath_config_message(dp_id, DC_ICMP);

        return dp_id == RFVS_DPID

    # DatapathDown methods
    def set_dp_down(self, dp_id):
        for entry in self.rftable.get_dp_entries(dp_id):
            # For every port registered in that datapath, put it down
            self.set_dp_port_down(entry.dp_id, entry.dp_port)

    def set_dp_port_down(self, dp_id, dp_port):
        entry = self.rftable.get_entry_by_dp_port(dp_id, dp_port)
        if entry is not None:
            # If the DP port is registered, delete it and leave only the
            # associated VM port. Reset this VM port so it can be reused.
            vm_id, vm_port = entry.vm_id, entry.vm_port
            entry.make_idle(RFENTRY_IDLE_VM_PORT)
            self.rftable.set_entry(entry)
            self.reset_vm_port(vm_id, vm_port)

    def reset_vm_port(self, vm_id, vm_port):
        # TODO: implement
        pass

    # PortMap methods
    def map_port(self, vm_id, vm_port, vs_id, vs_port):
        entry = self.rftable.get_entry_by_vm_port(vm_id, vm_port)
        if entry is not None and entry.get_status() == RFENTRY_ASSOCIATED:
            # If the association is valid, activate it
            entry.activate(vs_id, vs_port)
            self.rftable.set_entry(entry)
            msg = DataPlaneMap(dp_id=entry.dp_id, dp_port=entry.dp_port,
                               vs_id=vs_id, vs_port=vs_port)
            self.ipc.send(RFSERVER_RFPROXY_CHANNEL, RFPROXY_ID, msg)


if len(sys.argv) == 2:
    configfile = sys.argv[1]
    try:
        RFServer(configfile)
    except IOError:
        sys.exit("Error opening file: {}".format(configfile))
else:
    sys.exit("Invalid parameters.\n"\
             "Usage:\n"\
             "  ./server.py [configfile]\n"\
             "    configfile: path to CSV configuration file")