#!/usr/bin/env bats

# Tests for resolve-version-ref.sh.
# Stubs the `gh` CLI via PATH so tests run hermetically.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../resolve-version-ref.sh"
  STUB_DIR="$(mktemp -d)"
  cp "${BATS_TEST_DIRNAME}/helpers/gh-stub.sh" "${STUB_DIR}/gh"
  chmod +x "${STUB_DIR}/gh"
  export PATH="${STUB_DIR}:${PATH}"

  GITHUB_OUTPUT="$(mktemp)"
  export GITHUB_OUTPUT
}

teardown() {
  rm -rf "$STUB_DIR"
  rm -f "$GITHUB_OUTPUT"
}

@test "workflow_dispatch: resolves draft release to version + ref" {
  local sha="a1b2c3d4e5f6789012345678901234567890abcd"
  export EVENT_NAME=workflow_dispatch
  export INPUT_VERSION=v1.2.3
  export GH_TOKEN=fake
  export GH_STUB_RESPONSE="{\"draft\":true,\"target_commitish\":\"${sha}\",\"tag_name\":\"v1.2.3\"}"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version=v1.2.3$" "$GITHUB_OUTPUT"
  grep -q "^ref=${sha}$" "$GITHUB_OUTPUT"
}

@test "workflow_dispatch: errors if no release found" {
  export EVENT_NAME=workflow_dispatch
  export INPUT_VERSION=v9.9.9
  export GH_TOKEN=fake
  export GH_STUB_RESPONSE=""

  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No release found"* ]]
}

@test "workflow_dispatch: errors if release is already published" {
  export EVENT_NAME=workflow_dispatch
  export INPUT_VERSION=v1.0.0
  export GH_TOKEN=fake
  export GH_STUB_RESPONSE='{"draft":false,"target_commitish":"abc","tag_name":"v1.0.0"}'

  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already published"* ]]
}

@test "workflow_dispatch: fails when INPUT_VERSION missing" {
  export EVENT_NAME=workflow_dispatch
  export GH_TOKEN=fake
  unset INPUT_VERSION || true

  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"INPUT_VERSION"* ]]
}

@test "workflow_dispatch: fails when GH_TOKEN missing" {
  export EVENT_NAME=workflow_dispatch
  export INPUT_VERSION=v1.2.3
  unset GH_TOKEN || true

  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"GH_TOKEN"* ]]
}

@test "fails when EVENT_NAME missing" {
  unset EVENT_NAME || true
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"EVENT_NAME"* ]]
}

@test "fails when GITHUB_OUTPUT missing" {
  export EVENT_NAME=workflow_dispatch
  export INPUT_VERSION=v1.2.3
  export GH_TOKEN=fake
  unset GITHUB_OUTPUT || true

  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"GITHUB_OUTPUT"* ]]
}

@test "release event: uses RELEASE_TAG_NAME and RELEASE_TARGET directly" {
  local sha="a1b2c3d4e5f6789012345678901234567890abcd"
  export EVENT_NAME=release
  export RELEASE_TAG_NAME=v2.0.0
  export RELEASE_TARGET="$sha"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version=v2.0.0$" "$GITHUB_OUTPUT"
  grep -q "^ref=${sha}$" "$GITHUB_OUTPUT"
}

@test "release event: fails when RELEASE_TAG_NAME missing" {
  export EVENT_NAME=release
  export RELEASE_TARGET=abc

  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"RELEASE_TAG_NAME"* ]]
}
