#!/usr/bin/env python3
"""Compute compact MetalLB pools from container network subnets."""

import ipaddress
import sys

DEFAULT_IPV4_POOL = "172.18.255.200-172.18.255.250"
# The action configures Docker's fixed IPv6 network as 2001:db8:1::/64. Use
# its last /120 slice so the fallback avoids the low addresses used by Docker.
DEFAULT_IPV6_POOL = "2001:db8:1:0:ffff:ffff:ffff:ff00/120"


def ipv4_range(network):
    """Match quick-k8s's existing IPv4 range construction."""
    octets = str(network.network_address).split(".")
    if network.prefixlen <= 16:
        start = f"{octets[0]}.{octets[1]}.255.200"
        end = f"{octets[0]}.{octets[1]}.255.250"
    else:
        start = f"{octets[0]}.{octets[1]}.{octets[2]}.200"
        end = f"{octets[0]}.{octets[1]}.{octets[2]}.250"
    return f"{start}-{end}"


def ipv6_prefix(network):
    """Use at most a /120 from large networks, avoiding the full /64 pool."""
    pool_prefix = max(network.prefixlen, 120)
    return str(
        ipaddress.ip_network(
            (int(network.broadcast_address), pool_prefix), strict=False
        )
    )


def parse_networks(raw_subnets):
    networks = {4: None, 6: None}
    for subnet in raw_subnets.split():
        try:
            network = ipaddress.ip_network(subnet, strict=False)
        except ValueError:
            print(f"::warning::Ignoring invalid container subnet '{subnet}'", file=sys.stderr)
            continue
        if networks[network.version] is None:
            networks[network.version] = network
    return networks


def get_pool_addresses(family, raw_subnets):
    if family not in ("ipv4", "ipv6", "dual"):
        raise ValueError(f"unsupported IP family: {family}")

    networks = parse_networks(raw_subnets)
    addresses = []

    if family in ("ipv4", "dual"):
        if networks[4] is None:
            print(
                f"::warning::Could not detect IPv4 container subnet, using default {DEFAULT_IPV4_POOL}",
                file=sys.stderr,
            )
            addresses.append(DEFAULT_IPV4_POOL)
        else:
            addresses.append(ipv4_range(networks[4]))

    if family in ("ipv6", "dual"):
        if networks[6] is None:
            print(
                f"::warning::Could not detect IPv6 container subnet, using default {DEFAULT_IPV6_POOL}",
                file=sys.stderr,
            )
            addresses.append(DEFAULT_IPV6_POOL)
        else:
            addresses.append(ipv6_prefix(networks[6]))

    return addresses


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <ipv4|ipv6|dual> <subnets>", file=sys.stderr)
        return 2

    try:
        addresses = get_pool_addresses(sys.argv[1], sys.argv[2])
    except ValueError as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1

    print("\n".join(addresses))
    return 0


if __name__ == "__main__":
    sys.exit(main())
