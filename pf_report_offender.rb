#!/usr/bin/env ruby

# Constants definition
OFFENDING_STATE_NUMBER = 10_000
IP_RX = /(\d{1,3}.){3}\d{1,3}/
PORT_RX = /\d{1,5}/

# Initializing varibles
h_states = {}

# Creates a hash out of pfctl output
#   key: source ip
#   value: number of states initiated by this source ip
pf_output = open("|pfctl -ss")
pf_output.each do |line|
  next unless line[/\(?(#{IP_RX}):(#{PORT_RX})\)? (->|<-) (#{IP_RX}):(#{PORT_RX})/] 
  src, src_port, dir, dst, dst_port = case $4
    when '->' then [$1, $3, $4, $5, $7]
    when '<-' then [$5, $7, $4, $1, $3]
  end
  h_states[src] ||= 0
  h_states[src] += 1
end

# Print some output if an offender is found
h_states.each do |key, value|
  if value > OFFENDING_STATE_NUMBER
    puts "Offending host detected: #{key} currently has #{value} states"
  end
end
