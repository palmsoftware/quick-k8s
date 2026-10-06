#!/usr/bin/env bats

POOL_SCRIPT="$BATS_TEST_DIRNAME/../scripts/metallb-address-pool.py"

@test "preserves the IPv4 pool range and ignores IPv6 in ipv4 mode" {
  run python3 "$POOL_SCRIPT" ipv4 "172.18.0.0/16 fc00:f853:ccd:e793::/64"

  [ "$status" -eq 0 ]
  [ "$output" = "172.18.255.200-172.18.255.250" ]
}

@test "dual mode emits IPv4 and a narrow IPv6 prefix in the same pool" {
  run python3 "$POOL_SCRIPT" dual "172.18.0.0/16 fc00:f853:ccd:e793::/64"

  [ "$status" -eq 0 ]
  [ "$output" = $'172.18.255.200-172.18.255.250\nfc00:f853:ccd:e793:ffff:ffff:ffff:ff00/120' ]
}

@test "ipv6 mode emits only the detected IPv6 prefix" {
  run python3 "$POOL_SCRIPT" ipv6 "172.18.0.0/16 fc00:f853:ccd:e793::/64"

  [ "$status" -eq 0 ]
  [ "$output" = "fc00:f853:ccd:e793:ffff:ffff:ffff:ff00/120" ]
}

@test "keeps detected IPv6 subnets narrower than /120" {
  run python3 "$POOL_SCRIPT" ipv6 "fc00:f853:ccd:e793::/124"

  [ "$status" -eq 0 ]
  [ "$output" = "fc00:f853:ccd:e793::/124" ]
}

@test "IPv4 ranges keep the prior behavior for narrower networks" {
  run python3 "$POOL_SCRIPT" ipv4 "192.168.49.0/24"

  [ "$status" -eq 0 ]
  [ "$output" = "192.168.49.200-192.168.49.250" ]
}

@test "dual mode uses documented defaults for missing address families" {
  run python3 "$POOL_SCRIPT" dual ""

  [ "$status" -eq 0 ]
  [[ "$output" == *"172.18.255.200-172.18.255.250"* ]]
  [[ "$output" == *"2001:db8:1:0:ffff:ffff:ffff:ff00/120"* ]]
}

@test "uses defaults when the container subnet data is invalid" {
  run python3 "$POOL_SCRIPT" dual "not-a-subnet"

  [ "$status" -eq 0 ]
  [[ "$output" == *"172.18.255.200-172.18.255.250"* ]]
  [[ "$output" == *"2001:db8:1:0:ffff:ffff:ffff:ff00/120"* ]]
  [[ "$output" == *"Ignoring invalid container subnet"* ]]
}

@test "rejects unsupported IP families" {
  run python3 "$POOL_SCRIPT" invalid "172.18.0.0/16"

  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported IP family"* ]]
}
