# Interview questions: base-sepolia-token

## Q1. What exactly does "verified on Basescan" prove, and what doesn't it prove?

Answer: Verification proves that a given source file, compiled with given settings, produces exactly the bytecode
stored at that address. The explorer takes my source (here `PlayToken.sol` plus the OpenZeppelin files), compiles it
with the compiler version, optimizer runs and EVM version I submit, and compares the result to the code on-chain.
The settings matter because a different `solc` version or optimizer setting produces different bytecode, which is
why `foundry.toml` pins `0.8.30`, 200 runs and `prague`. Constructor arguments matter too: they're appended to the
creation code, so the explorer needs them (my address and 10,000 PLAY, ABI-encoded) to reproduce the deployment.
What verification doesn't prove is that the code is safe, or that this is the "official" PlayToken. Anyone can
deploy and verify a contract with the same name. It turns "trust me" into "read it yourself", nothing more. I can
also check it without trusting the explorer by comparing `cast code` on-chain with `forge inspect`'s
`deployedBytecode`.

## Q2. How did I keep the deployer key safe, and what would I change for a production stablecoin deployment?

Answer: The key never exists in plaintext in any file. It lives in an encrypted Foundry keystore outside the repo,
and `--account deployer` decrypts it in memory only to sign. I used two terminal windows: Claude Code builds, tests
and simulates (a simulation only needs my public address), while every command that needs the key or password runs
in a plain shell Claude can't see. `.claude/settings.json` denies Claude access to `.env`, the keystore and commands
like `cast wallet private-key`, but I tested those rules and they're an enumeration, so commands like `grep -r` or
an alias can slip past without the OS-level sandbox. gitleaks scans the full git history in CI as a last net, and if
a real key ever leaked I'd rotate it immediately, because deleting a branch doesn't remove the commit. For a
production stablecoin I'd deploy from a hardware wallet or a KMS-backed signer, never a hot key on a laptop. I'd
transfer ownership right after deployment to a multisig, ideally behind a timelock, use `Ownable2Step`, and add
monitoring on owner actions.

## Q3. My token has a public faucet with a per-address daily cooldown. How would an attacker drain it, and what protects the supply?

Answer: The cooldown is tracked per address, and addresses are free, so an attacker generates thousands of keys and
calls `claim()` once from each, getting 100 PLAY per address. That's a sybil attack: one actor pretending to be
many users. What actually protects the supply is `MAX_SUPPLY`. Every mint goes through `_mintCapped`, so the total
can never pass 1,000,000 PLAY, no matter how many addresses claim. The damage is a denial of service: once the cap is
reached, honest users' claims and even the owner's `mint()` revert with `CapExceeded`. Real faucets make identities
expensive. Alchemy's Base Sepolia faucet requires at least 0.001 ETH on Ethereum mainnet in the receiving address,
which a freshly generated wallet doesn't have. Others require an account, a captcha or a social login, and some rate
limit by IP. Each of these raises the cost per fake identity rather than stopping sybils completely.

## Q4. A deploy script used `address(this)` as the token owner and all 12 contract tests stayed green. What would have happened, and what caught it?

Answer: Inside a Foundry script, `address(this)` is the script contract, which only exists during the local
simulation and is never deployed. The token would have made that address its owner and sent it the 10,000 PLAY
initial mint. Nobody holds a key for it, so `mint()` and `transferOwnership()` could never be called and the
initial supply would be stuck forever, on a contract that can't be edited. The 12 tests missed it because every one
of them builds `new PlayToken(owner, INITIAL)` directly and never runs the deploy script. In my project, the
`/code-review high` run flagged it as its top, critical finding, and the new `test_ScriptMakesTheCallerOwner` test
failed on it (`0x5615… != 0x7FA9…`) and passes after the fix. Foundry also has a guard that refuses `address(this)`
in script contracts during simulation. My own simulation stopped earlier on "lack of funds", so I didn't see that
guard fire myself. The lesson: deployment code is code, so it needs tests.

## Q5. Give a checklist for moving this deployment from testnet to mainnet.

Answer: Point at Base mainnet (chain ID 8453) with a reliable RPC, and update the `[rpc_endpoints]` and `[etherscan]`
entries. Confirm the target chain supports the pinned EVM version (`prague`) before deploying, or the bytecode may
use opcodes it doesn't have. Get the code audited, run the full test suite and a fork test against mainnet state,
then simulate the exact deploy command and check the gas estimate against the real ETH balance. Deploy only from
reviewed, merged, tagged `main`, from a hardware wallet or KMS signer, never a hot keystore. Verify the source right
away and compare the on-chain bytecode hash with a local build. Move ownership to a multisig with a timelock using a
two-step transfer, and decide whether a public faucet should exist at all on mainnet. Set up monitoring and alerts
for `OwnershipTransferred`, large mints and supply approaching the cap. Restrict permissions further than on
testnet: no AI agent or shared terminal near the signer, and secrets in a vault rather than `.env`.
