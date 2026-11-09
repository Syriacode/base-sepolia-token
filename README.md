# base-sepolia-token

An ERC-20 token deployed and verified on Base Sepolia with Foundry, keeping secrets out of the repo.

Part of my [learning roadmap](https://github.com/Syriacode/Mini-Blockchain/blob/main/ROADMAP.md).

| | |
|---|---|
| Language | solidity |
| Claude Code technique practiced | secrets safety (deny `.env`), `/code-review` |

## Run it

```bash
forge build
forge test -vv
forge fmt --check
```

## Design decisions

- **One mint path.** The constructor, `claim()` and `mint()` all go through one internal function,
  `_mintCapped`, and nothing else calls `_mint`. The `MAX_SUPPLY` check lives in exactly one place.
- **The cap protects the supply, not the cooldown.** `claim()` gives 100 PLAY per address per day. That slows down
  a normal user, but not someone with many addresses. `MAX_SUPPLY` (1,000,000 PLAY) is the hard limit the contract
  enforces.
- **Pinned compiler and EVM version.** `solc_version = "0.8.30"` and `evm_version = "prague"` in `foundry.toml`.
  Verification recompiles the source and compares bytecode, so the settings must be the same on deploy day and
  verify day.
- **Foundry keystore, not a private key in `.env`.** The deployer key lives encrypted in `~/.foundry/keystores/`,
  outside the repo. `--account deployer` decrypts it in memory to sign. `.env` holds only a revocable Etherscan
  API key.
- **Two terminal windows.** Claude Code builds, tests and simulates. Anything that needs the key or its password
  (creating the wallet, `--broadcast`, `cast send`) runs in a separate plain shell, so Claude never handles either.
- **Deny rules in `.claude/settings.json`.** They block Claude from reading `.env` and the keystore and from
  commands like `cast wallet private-key`. They're a seatbelt, not a wall (see Known limitations).
- **gitleaks scans the full git history in CI.** It uses `fetch-depth: 0`, verifies the download against its SHA-256
  checksum, and runs with `--redact` so a finding doesn't leak into public logs.
- **Deploy only reviewed, merged `main`.** Work happens on a branch, gets reviewed with `/code-review` and merged
  through a PR with green CI. Only then is it deployed. The deploy script has a test that checks the caller becomes
  the owner.

## Known limitations

- **The faucet is sybil-able.** Every new address gets a new claim, so a script with many addresses can mint until
  `MAX_SUPPLY` is reached. After that, `claim()` and `mint()` revert with `CapExceeded`.
- **The owner can mint up to the cap, and ownership is single-step.** A typo in `transferOwnership` or an
  accidental `renounceOwnership` loses minting forever. OpenZeppelin's `Ownable2Step` would add an accept step.
- **The deployer key is a hot key.** A production deployment would sign with a hardware wallet or a KMS, then hand
  ownership to a multisig or a timelock.
- **Deny rules are best-effort.** Without the sandbox (not available on native Windows), commands that read files
  without naming them, such as `grep -r`, can get around them.
- **Base Sepolia is a testnet** and will be retired one day, along with this deployment.
- **Reviewer findings I decided not to fix** (from `/code-review high`):
  - `testFuzz_SupplyNeverExceedsCap` swallows every revert in an empty `catch`, so it can't tell a correct
    `CapExceeded` from an unrelated failure.
  - The deploy script only logs `token.owner()`. It doesn't `require` that the owner is the broadcaster. The
    script test covers this instead.
