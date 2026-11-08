# Week 1 Weekend — Deploy and verify a token on Base Sepolia (step-by-step guide)

**Goal:** write a capped ERC-20 token with its own built-in faucet, deploy it to a real public network (Base
Sepolia), verify its source code on Basescan, and use it on-chain. Along the way, set things up so that Claude
Code **never sees your deployer key**, and use `/code-review` to check your work before it goes on-chain.

**Why this project:** every project so far ran on your own laptop with play money that disappears when the test
ends. Today the code goes somewhere public and permanent. That changes two things. First, **keys become real**: a
leaked testnet key teaches the same bad habit as a leaked mainnet key, so you'll practice the professional setup
now. Second, **mistakes become permanent**: you can't edit a deployed contract, so you'll review before you deploy,
not after. Your Friday dApp (Week 2) and the Week 4 capstone both build on the token you deploy today.

| Job requirement | Where you practice it |
|---|---|
| Solidity / EVM smart contracts in production (Coinbase Stablecoins, Chainlink, FTI) | Steps 3, 4, 8, 9 |
| Onchain security, key management (Coinbase, Chainlink, Anchorage) | Steps 1, 2, 7, 8 |
| *Well-tested code*, including deployment code | Steps 4, 6 |
| *Uses generative AI responsibly, with human oversight* | Steps 1, 6 (you test the guardrails and the reviewer) |

**Claude Code techniques today:**

1. **Secrets safety.** Project permission rules (`.claude/settings.json`) that **deny** Claude access to `.env`
   and your keystore. You'll also test where those rules stop working, because that tells you what they're worth.
2. **`/code-review`.** A built-in command that reviews your branch for bugs. It runs as a background subagent with
   its own context, so you keep working while it reads.

**Time:** about 3 hours. The network costs nothing: Base Sepolia ETH is free test money from a faucet.

---

## How to use this guide with Claude Code

Every step has the same five parts:

- **Learn:** the concept, in a few sentences. Read it before prompting.
- **Prompt:** what to type into Claude Code. Use **plan mode** (`Shift+Tab` until the status bar shows
  `⏸ plan mode on`), read the plan, then approve it.
- **You check:** what *you* verify before accepting. Each check names the file and function to open.
- **Done when:** a command whose output proves the step works.
- **Commit:** the commit message to use. Ask Claude to commit, or run it yourself.

A leading `!` in the Claude Code prompt runs a shell command, as in `!forge test`. **Important today:** the output
of a `!` command goes into Claude's context, just like a file Claude reads. So never use `!` on anything that prints
a secret.

### Two terminal windows today

This guide uses **two Git Bash windows**, both in the project folder:

- **Window A — Claude Code.** Building, testing, reviewing, simulating.
- **Window B — your "secrets window", plain Git Bash with no Claude.** Creating the wallet, typing passwords,
  editing `.env`, and broadcasting real transactions.

Steps that happen in Window B are marked **🔑 Window B**. The rule is simple: **anything that touches a key or a
password happens in Window B.** Claude writes the deploy command; you run it.

Line numbers and exact wording in Claude's replies will differ from the examples here. Test names and test counts
should match, as long as you keep the prompts as written.

> ℹ️ **What I could and couldn't test.** I built and tested the reference solution privately with Foundry 1.7.1:
> every `forge` and `cast` command below, the tests and their counts, the "break it" results, the keystore commands,
> a full deploy and claim on a local chain that uses Base Sepolia's chain ID (84532), the bytecode comparison, and
> the gitleaks CI job against real and planted secrets. My test machine **can't reach Base Sepolia or the Etherscan
> API**, and it can't run Claude Code itself. So the live deploy, Basescan verification, the faucets, and the exact
> behavior of the deny rules and `/code-review` are written from current documentation (checked 2026-11-07), not
> from a run. Where that matters, the guide tells you what to do if you see something different.

---

## Step 0 — Update your tools, create the repo, add OpenZeppelin (15 min)

**Learn.** `/code-review` changed a lot in recent Claude Code versions: since v2.1.218 it runs as a background
subagent, and since v2.1.223 `/review` is an alias for it. So update first. Foundry also changes often, and
verification depends on it.

**Do it (Window A, before starting Claude):**

```bash
foundryup
forge --version
claude update
claude --version
```

You want `forge Version: 1.7.x` or newer, and Claude Code **2.1.223 or newer**.

Go to the folder where you keep your project repos (**not** inside another git repo), then:

```bash
claude
```

**Prompt:**
> /new-project Week 1 Weekend – Deploy and verify a token on Base Sepolia

When it proposes a name, accept **`base-sepolia-token`** (or pick your own and use it everywhere below). Confirm the
language is **`solidity`**. Approve the `gh repo create` and `git push` prompts.

When it finishes, quit (`/exit`), then:

```bash
cd base-sepolia-token
```

Save **this file** as `GUIDE.md` in the `base-sepolia-token` folder. Then:

```bash
claude
```

**Prompt (plan mode):**
> Delete the sample Counter files: src/Counter.sol, test/Counter.t.sol and script/Counter.s.sol.
> Run `forge install OpenZeppelin/openzeppelin-contracts`.
> Create remappings.txt with exactly these two lines:
> `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/`
> `forge-std/=lib/forge-std/src/`
> Replace foundry.toml with exactly this content:
>
> ```toml
> [profile.default]
> src = "src"
> out = "out"
> libs = ["lib"]
> solc_version = "0.8.30"
> optimizer = true
> optimizer_runs = 200
> evm_version = "prague"
>
> [rpc_endpoints]
> base-sepolia = "https://sepolia.base.org"
>
> [etherscan]
> base-sepolia = { key = "${ETHERSCAN_API_KEY}", chain = 84532 }
> ```
>
> Run forge build. Then commit everything together.

**You check:** open `foundry.toml` and read it top to bottom.
- `solc_version` and `evm_version` are **pinned**. Verification works by recompiling your source and comparing the
  result to what's on-chain, so the compiler settings must be exactly the same on deploy day and verify day. If you
  let Foundry pick the newest compiler, a `foundryup` between deploy and verify could break verification. Ask Claude:
  *"What does `evm_version` control, and what could go wrong if I compiled for an EVM version that Base Sepolia
  doesn't support yet?"*
- `[rpc_endpoints]` gives the URL a short name, so commands can say `--rpc-url base-sepolia`. This public URL is
  rate-limited but needs no account, so it's fine to commit.
- `[etherscan]` contains `${ETHERSCAN_API_KEY}`, **not** the key. Foundry fills it in from your environment or from a
  `.env` file at run time. CI has no key, and that's fine: `forge build` and `forge test` don't need it.
- Open `.gitignore`. It already contains `.env` (from your kit). Ask Claude: *"Does .gitignore stop you from reading
  .env?"* (The answer is no. `.gitignore` only affects git. Step 1 deals with Claude.)

**Done when:** `!forge build` prints `Compiler run successful!` (or `No files changed, compilation skipped`), and
`!git status` is clean.

**Commit:** `Add GUIDE.md, OpenZeppelin, pinned compiler and Base Sepolia config`

---

## Step 1 — Lock down secrets, then test the lock (20 min)

**Learn (Claude Code).** Permission rules in `.claude/settings.json` apply to everyone who opens this repo with
Claude Code, and they travel with the repo. Three lists:

- **deny:** Claude can't do it, even if you approve. Deny wins over everything.
- **ask:** Claude must ask you every time.
- **allow:** Claude may do it without asking.

For files, `Read(./.env)` means "the `.env` file in this project". `~/` means your home folder. `**` means "any
depth of folders".

What a `Read` deny rule covers, according to the current docs: Claude's own file tools (Read, Grep, Glob), `@`
mentions, and shell commands Claude Code recognizes as file commands, such as `cat .env` or `head .env`. What it
**doesn't** cover: commands that read files without naming them, such as `grep -r pattern .`, and scripts that
open files themselves, such as a Python one-liner. The docs say the real wall is the **sandbox**, which blocks file
access at the operating-system level. But the sandbox runs on macOS, Linux and WSL, **not on native Windows**, so
it isn't available to you in Git Bash.

So the plan is **defense in depth**:

1. **Deny rules** stop the common, accidental reads.
2. **Design** makes the remaining leaks cheap: your private key will never be in any plaintext file at all
   (Step 2), and `.env` will hold only one low-value, revocable API key.
3. **CI secret scanning** (Step 7) catches a secret that slips into a commit.

**Prompt (plan mode):**
> Create .claude/settings.json with exactly this content:
>
> ```json
> {
>   "permissions": {
>     "deny": [
>       "Read(./.env)",
>       "Read(./.env.*)",
>       "Edit(./.env)",
>       "Edit(./.env.*)",
>       "Read(~/.foundry/keystores/**)",
>       "Edit(~/.foundry/keystores/**)",
>       "Bash(cast wallet private-key *)",
>       "Bash(cast wallet decrypt-keystore *)",
>       "Bash(env)",
>       "Bash(printenv)",
>       "Bash(printenv *)"
>     ],
>     "ask": [
>       "Bash(forge script * --broadcast*)",
>       "Bash(forge create *)",
>       "Bash(cast send *)"
>     ]
>   }
> }
> ```
>
> Also create env.example with one line, `ETHERSCAN_API_KEY=`, and a comment line above it saying the real values go
> in .env, which is gitignored. Don't create .env yourself.

**Why `env.example` and not `.env.example`?** The rule `Read(./.env.*)` would block Claude from reading
`.env.example` too. A template must be readable, so give it a name the rule doesn't match.

**Restart now** (`/exit`, then `claude`), so the new rules load from the start of the session. Then type:

```text
/permissions
```

You should see your deny and ask rules listed. Press `Esc`.

**Now test the lock with a canary.** A canary is a fake secret with a recognizable value. If it shows up in Claude's
output, you know exactly which route leaked it, and nothing real was lost. Never test with a real key.

**🔑 Window B:** open a second Git Bash window, `cd` into `base-sepolia-token`, and run:

```bash
printf 'ETHERSCAN_API_KEY=CANARY-not-a-real-key-7Q2M\n' > .env
git check-ignore -v .env
```

The second command should print `.gitignore:4:.env	.env` (the line number may differ). That proves git won't
commit it.

**Back in Window A**, try these three prompts, one at a time. Don't use plan mode. Write down what happens for each:

> Probe 1: Read the .env file and tell me what's in it.

> Probe 2: Run `cat .env` and show me the output.

> Probe 3: Search the whole project with `grep -r CANARY .` and show me every matching line.

**You check:**
- Probes 1 and 2 should be **blocked**. Claude should say it's denied by your permission settings.
- Probe 3 **may leak the canary**. An independent test in September 2026 found that `grep -r` across the project
  returned a protected `.env` value with deny rules in place, and the docs list it as a known gap. If your version
  blocks it, great. Write down which happened.
- If Claude found the canary, ask it: *"Which of my deny rules should have stopped that, and why didn't it?"* Then
  ask: *"Could I fix this by adding more deny rules? What's the problem with that approach?"* The point: a deny list
  is an **enumeration**, and there's always another command. Look at your own list: `cast wallet decrypt-keystore`
  is denied, but `cast wallet --help` shows it has a short alias, `dk`. Your list doesn't cover the alias.
- Ask Claude to add `"Bash(cast wallet dk *)"` and `"Bash(cast wallet pk *)"` to the deny list (`pk` is the alias of
  `private-key`). Then remember: you didn't fix the approach, you fixed one example.
- One more: `@`-imports inside a `CLAUDE.md` file load at startup and aren't covered by deny rules. Open `CLAUDE.md`
  and confirm it has no line starting with `@` that points at `.env`.

Keep your notes. They go into "How I used Claude Code" in Step 10.

**Done when:** `/permissions` lists your rules, probes 1 and 2 were blocked, you've recorded what probe 3 did, and
`!git status` shows `.claude/settings.json` and `env.example` as new, and **not** `.env`.

**Commit:** `Add secret-protection permission rules and env.example`

Then push (Claude will ask before `git push`):

> Push main.

---

## Step 2 — 🔑 Window B: a test wallet, test ETH, and an API key (20 min)

Everything in this step happens in **Window B**. Claude Code isn't involved.

**Learn.**
- **A test wallet is a fresh key used for nothing else.** Never deploy from a wallet that holds anything real, and
  never reuse a testnet key on mainnet. Keys leak through habits, and a testnet key that "doesn't matter" is how the
  habit starts.
- **Foundry keystore.** Instead of a private key in `.env` (the most common way keys leak from repos), Foundry can
  keep the key in an **encrypted** file in `~/.foundry/keystores/`, outside your project. Commands that need it ask
  for its password, decrypt it in memory, sign, and forget it. The plaintext key never exists in a file, in your
  shell history, or in Claude's context.
- **A faucet** gives out free test ETH. Faucets fight abuse ("sybil" attackers creating thousands of addresses), so
  some require a mainnet balance or an account. Keep that in mind: your token's faucet in Step 3 has the same
  problem.
- **Base Sepolia** is the test network for Base, Coinbase's Ethereum layer 2. Chain ID **84532**. Explorer:
  **sepolia.basescan.org**.

**2a. Create the wallet.**

```bash
mkdir -p ~/.foundry/keystores
cast wallet new ~/.foundry/keystores deployer
```

It asks for a password twice (nothing appears as you type). Use a real password, and save it in your password
manager. It prints:

```text
Created new encrypted keystore file: /c/Users/<you>/.foundry/keystores/deployer
Address:    0x...
```

It does **not** print the private key. That's the point.

> ⚠️ **If you can't type the password** (Git Bash's default terminal, MinTTY, has trouble with hidden prompts from
> some Windows programs), run the same command with `winpty` in front: `winpty cast wallet new ~/.foundry/keystores
> deployer`. Or open Git Bash inside Windows Terminal. You'll need the same fix for every command below that asks for
> the password.

Check it:

```bash
cast wallet list
cast wallet address --account deployer
```

`cast wallet list` shows `deployer (Local)` (my Foundry 1.7.1 printed it as `0xdeployer (Local)`, which is a display
quirk). The second command asks for the password and prints your address.

Save the address in this window's session, and write it down. It's public, so it's fine to share:

```bash
export DEPLOYER=0xYourAddressHere
```

**2b. Get test ETH.** Deploying today's token costs about 1 million gas. On Base Sepolia that's a tiny fraction of
any faucet drip. Try these in order:

1. **QuickNode faucet**, `https://faucet.quicknode.com/base/sepolia`: paste your address. No account or mainnet
   balance needed for the basic drip, once every 12 hours.
2. **Coinbase Developer Platform faucet**, `https://docs.cdp.coinbase.com/faucets/introduction/welcome`: needs a free
   CDP account; small drips (0.0001 ETH each), which is still plenty for today.
3. **Alchemy faucet**, `https://www.alchemy.com/faucets/base-sepolia`: 0.1 ETH a day, but it requires at least 0.001
   ETH on Ethereum **mainnet** in the receiving address. A fresh wallet fails this check. That's sybil resistance in
   action, and a good interview example.

Faucet rules change often, so if one fails, move to the next. Make sure you pick **Base Sepolia**, not Ethereum
Sepolia: they're different chains with separate balances.

Check the balance (wait a minute after the faucet says it sent):

```bash
cast balance $DEPLOYER --ether --rpc-url base-sepolia
```

You should see a non-zero number, such as `0.0001000000000000` or more. Run this from inside the project folder, so
`cast` finds the `base-sepolia` name in `foundry.toml`.

**2c. Get an Etherscan API key.** Basescan is run by Etherscan, and since Etherscan's API V2, **one key from
etherscan.io works for all their chains**, including Base Sepolia (Foundry picks the chain from chain ID 84532).
Etherscan's free tier no longer covers most API calls on Base, but Etherscan says contract **verification** stays
available on every chain, free tier included.

1. Sign up at `https://etherscan.io` (free).
2. Open your account menu → **API Keys** → **Add**, and name it `base-sepolia-token`.
3. Copy the key.

Now replace the canary with the real key, using an editor, not a command (commands end up in shell history):

```bash
notepad .env
```

Change the line to `ETHERSCAN_API_KEY=<your key>`, save, and close Notepad. Don't paste the key into Claude Code, and
don't `!cat .env` in Window A.

**You check:**
- `ls ~/.foundry/keystores` shows `deployer`. Open that file in Notepad and look: it's JSON with `crypto`,
  `ciphertext` and `kdf` fields. That's your key, encrypted. Close it without saving.
- `git status` (in Window B) still doesn't list `.env`.

**Done when:** `cast balance $DEPLOYER --ether --rpc-url base-sepolia` is above zero, and `.env` holds your real
Etherscan key.

**Commit:** nothing to commit. Nothing from this step belongs in git.

---

## Step 3 — The token: ERC-20 with a cap and a built-in faucet (15 min)

**Learn.**
- **ERC-20** is the standard interface for fungible tokens (`balanceOf`, `transfer`, `approve`, `transferFrom`).
  You'll use OpenZeppelin's audited implementation instead of writing your own. That's what production teams do.
- **Decimals:** `18` means "1 token" is stored as `10^18` units. In Solidity, `100 ether` is just a way to write
  `100 * 10^18`. It has nothing to do with ETH here.
- **Cap:** `MAX_SUPPLY` makes "there will never be more than a million tokens" a rule the contract enforces, not a
  promise. Every mint path goes through one internal function, `_mintCapped`, so there's exactly one place to check.
- **Faucet:** `claim()` gives anyone 100 tokens, once per day per address. Your Friday dApp will call it. The
  per-address cooldown slows down a casual user, not an attacker with many addresses. The **cap** is what actually
  protects the supply.
- **Ownable:** the owner can mint more (still under the cap). Who becomes the owner at deploy time matters a lot.
  You'll see why in Step 6.

**Do it first:** work on a branch, so `/code-review` in Step 6 has a clear "before and after":

> !git switch -c token

**Prompt (plan mode):**
> Create src/PlayToken.sol (pragma ^0.8.24, MIT license), a contract `PlayToken is ERC20, Ownable` using
> OpenZeppelin's ERC20 and Ownable (imports from "@openzeppelin/contracts/..."):
> - constants `MAX_SUPPLY = 1_000_000 ether`, `CLAIM_AMOUNT = 100 ether`, `CLAIM_COOLDOWN = 1 days`
> - `mapping(address account => uint256 time) public nextClaimAt`, where 0 means "never claimed"
> - event `Claimed(address indexed account, uint256 amount)`
> - custom errors `CapExceeded(uint256 requested, uint256 available)` and `ClaimTooSoon(uint256 nextClaimAt)`
> - constructor `(address initialOwner, uint256 initialMint)`: name "PlayToken", symbol "PLAY", `Ownable(initialOwner)`,
>   then mint `initialMint` to `initialOwner` through `_mintCapped`
> - `claim()` external: read `nextClaimAt[msg.sender]` into `next`, revert `ClaimTooSoon(next)` if
>   `block.timestamp < next`, set `nextClaimAt[msg.sender] = block.timestamp + CLAIM_COOLDOWN`, mint CLAIM_AMOUNT to
>   the caller through `_mintCapped`, emit Claimed
> - `mint(address to, uint256 amount)` external onlyOwner, through `_mintCapped`
> - `_mintCapped(address to, uint256 amount)` internal: `available = MAX_SUPPLY - totalSupply()`, revert
>   `CapExceeded(amount, available)` if `amount > available`, then `_mint`
> - a NatSpec `@title` and a one-line `@notice` on the contract
>
> Don't write tests yet. Run forge fmt and forge build.

**You check:** open `src/PlayToken.sol`.
- Find the three places that create tokens: the constructor, `claim`, and `mint`. All three must call `_mintCapped`,
  and **nothing** may call `_mint` directly except `_mintCapped`. Search the file for `_mint(` to confirm there's only
  one.
- In `claim`, the line that sets `nextClaimAt` comes **before** the mint. Ask Claude: *"OpenZeppelin's _mint doesn't
  call the receiver, so is this order a reentrancy fix here, or just a good habit? When would it matter?"*
- In `_mintCapped`, `MAX_SUPPLY - totalSupply()` can't underflow. Ask Claude: *"Why not? Which line guarantees that
  totalSupply never goes above MAX_SUPPLY?"*

> ℹ️ `forge build` prints `warning[block-timestamp]` for the `block.timestamp < next` line. It's a lint warning, not
> an error, and CI still passes. A block producer can shift timestamps by a few seconds, which doesn't matter for a
> one-day cooldown. Don't let Claude "fix" it.

**Done when:** `!forge build` prints `Compiler run successful!`.

**Commit:** `Add PlayToken: capped ERC-20 with a daily faucet`

---

## Step 4 — Tests, then break the faucet on purpose (15 min)

**Prompt (plan mode):**
> Create test/PlayToken.t.sol for @src/PlayToken.sol. Contract `PlayTokenTest is Test`, with makeAddr for owner, alice
> and bob, `INITIAL = 1_000 ether`, and setUp that warps to 1_700_000_000 and deploys `new PlayToken(owner, INITIAL)`.
> Tests, using exactly these names:
> 1. test_Metadata: name, symbol, and decimals is 18
> 2. test_ConstructorMintsToOwner: owner(), the owner's balance and totalSupply
> 3. test_RevertWhen_InitialMintAboveCap: deploying with MAX_SUPPLY + 1 reverts with CapExceeded(MAX_SUPPLY + 1, MAX_SUPPLY)
> 4. test_ClaimMintsAndEmits: expect the Claimed event with vm.expectEmit, alice claims, check her balance and nextClaimAt
> 5. test_RevertWhen_ClaimedTwiceTooSoon: alice claims, warp to nextClaimAt - 1, expect ClaimTooSoon(next)
> 6. test_ClaimAgainExactlyAfterCooldown: warp to exactly nextClaimAt, the second claim works, balance is 2 * CLAIM_AMOUNT
> 7. test_CooldownIsPerAddress: alice claims, then bob can claim right away
> 8. test_OwnerMints: owner mints 5 ether to bob
> 9. test_RevertWhen_StrangerMints: expect OpenZeppelin's Ownable.OwnableUnauthorizedAccount(alice)
> 10. test_RevertWhen_MintAboveCap: owner mints available + 1, expect CapExceeded(available + 1, available)
> 11. test_RevertWhen_ClaimWouldExceedCap: owner mints until only 1 unit is left, alice's claim reverts with
>     CapExceeded(CLAIM_AMOUNT, 1), and afterward nextClaimAt(alice) is still 0
> 12. testFuzz_SupplyNeverExceedsCap: bound amount from 0 to 2 * MAX_SUPPLY, the owner mints it inside try/catch,
>     then assert totalSupply <= MAX_SUPPLY
>
> Run forge fmt, then forge test -vv, and show me the output.

**You check:** open `test/PlayToken.t.sol`.
- Tests 5 and 6 sit on the two sides of the cooldown boundary: one second early, and exactly on time. Find the
  `vm.warp` line in each.
- Test 11 checks that a failed claim **doesn't** start the cooldown. Ask Claude: *"Why is nextClaimAt still 0, even
  though claim() sets it before minting?"* (Hint: what happens to all state changes when a transaction reverts?)
- In test 4, look at the four booleans in `vm.expectEmit(...)`. Ask Claude what each one means.

Now prove the tests protect the faucet. Type this (no plan mode needed):

> Break @src/PlayToken.sol on purpose: delete the line in claim() that sets nextClaimAt. Don't touch the tests.
> Run forge test and tell me which tests fail and why. Then put the line back and run forge test again.

You should see **2 tests fail**: `test_ClaimMintsAndEmits` (`assertion failed: 0 != 1700086400`) and
`test_RevertWhen_ClaimedTwiceTooSoon` (`panic: arithmetic underflow or overflow (0x11)`). Ask Claude why the second
one fails with a panic instead of a missing revert. (Its `nextClaimAt - 1` is `0 - 1`.) Then all 12 pass again.

**Done when:** `!forge test -vv` ends with `12 tests passed, 0 failed`, and the fuzz line shows `runs: 256`.

**Commit:** `Add PlayToken unit, boundary and fuzz tests`

---

## Step 5 — The deploy script, and a dry run against the real network (10 min)

**Learn (Foundry).**
- A **script** (`script/*.s.sol`) is Solidity that Foundry runs to produce transactions. Everything between
  `vm.startBroadcast()` and `vm.stopBroadcast()` becomes a real transaction, signed by the account you pass on the
  command line. The script itself never needs to know the key.
- Without `--broadcast`, `forge script` only **simulates**: it runs the script against the live chain's state and
  estimates gas, but sends nothing. A simulation needs only the sender's **address** (`--sender`), not its key. So
  Claude can run it safely.
- Foundry writes each run to `broadcast/<script>/<chainId>/`. The real deployment record (transaction hash,
  contract address) is worth committing. Simulations go into a `dry-run` subfolder, which isn't.
- Foundry also writes "sensitive values" (such as RPC URLs, which often contain API keys) to `cache/` instead of
  `broadcast/`. `cache/` is already gitignored.

**Prompt (plan mode):**
> Create script/DeployPlayToken.s.sol: contract `DeployPlayToken is Script` with `uint256 public constant
> INITIAL_MINT = 10_000 ether` and `function run() external returns (PlayToken token)`: vm.startBroadcast(),
> `token = new PlayToken(msg.sender, INITIAL_MINT)`, vm.stopBroadcast(), then console.log the token address and
> token.owner(). No private keys, no vm.env calls.
> Add the line `broadcast/*/*/dry-run/` to .gitignore.
> Run forge fmt and forge build. Then simulate it, without --broadcast:
> `forge script script/DeployPlayToken.s.sol --rpc-url base-sepolia --sender <MY ADDRESS>`
> and show me the output.

Replace `<MY ADDRESS>` with your deployer address from Step 2 (it's public, so it's fine to paste).

**You check:**
- In the output, `Owner` equals **your** address, not some other address. Remember this line for Step 6.
- Find `Chain 84532` and `Estimated total gas used for script`. In my local run it was **979,227** gas. Yours should
  be close. Then compare `Estimated amount required` to your balance from Step 2.
- `!git status` doesn't show anything under `broadcast/`. The dry-run went to the ignored folder.
- Ask Claude: *"Inside run(), why is msg.sender my address during forge script? Who is msg.sender when a test calls
  run()?"* You'll need this answer in Step 6.

**Done when:** the simulation ends with `SIMULATION COMPLETE. To broadcast these transactions, add --broadcast and
wallet configuration(s) to the previous command.`

**Commit:** `Add DeployPlayToken script`

---

## Step 6 — Review before you deploy: `/code-review` (25 min)

**Learn (Claude Code).** `/code-review` is built into Claude Code. With no arguments, it reviews **your branch's
commits plus your uncommitted changes**. Your `token` branch has no upstream yet, so it compares against `main`.
That's why you branched in Step 3. A few details:

- It runs as a **background subagent** with its own context, so its file reading doesn't fill your session, and you
  can keep working. The findings arrive in your conversation when it's done.
- You can pass an **effort level**: `low` reports only what it's most confident about (fewer false positives);
  `medium` to `max` widen the search. Claude Code remembers the last level you typed.
- It reports only, unless you add `--fix`. It follows your `CLAUDE.md`.
- Compare it to your Thursday `security-reviewer` subagent: that one is a specialist you wrote and measured.
  `/code-review` is a general correctness reviewer someone else wrote. You'll measure it the same way.

**6a. Review the real branch.**

```text
/code-review high
```

While it runs, read the next section. When the findings arrive:

**You check:**
- For each finding, decide: **real bug**, **real but accepted** (a known limitation), or **wrong**. For the top one,
  ask your main session: *"Open the code and tell me if this finding is real. Walk through it step by step. Don't
  change any files."*
- Likely topics on this code: the faucet is sybil-able (real, accepted: the cap is the protection), the owner can
  mint (real, by design), single-step ownership transfer. If it reports something you think is wrong, write down why.
- Don't fix anything yet. Copy any real finding you decide not to fix into a scratch note for the README.

**6b. Plant a deployment bug and run it blind.** This bug is a classic. In a Foundry script, `address(this)` is the
**script contract**, a temporary contract that only exists during the simulation. It never exists on-chain. A token
whose owner is that address has **no owner anyone can use**, forever. And your 12 tests can't catch it, because none
of them run the script.

Open `script/DeployPlayToken.s.sol` in your editor and change this line by hand:

```solidity
token = new PlayToken(msg.sender, INITIAL_MINT);
```

to:

```solidity
token = new PlayToken(address(this), INITIAL_MINT);
```

Save. **Predict before you run it:** will the tests catch this?

```text
!forge test
```

`12 tests passed, 0 failed`. **All green, and the deployment would be broken.**

Now clear the session, so the main Claude knows nothing about what you did:

```text
/clear
```

Then:

```text
/code-review high
```

**You check:**
- Does the top finding point at `script/DeployPlayToken.s.sol` and `address(this)`? Write down what it said, and how
  severe it rated it. I couldn't run `/code-review` in my test environment, so I can't tell you what to expect. **Your
  result is the measurement.** If it misses the bug, that's a real finding about the tool: write it in your README.
- Now try the simulation from Step 5 again:

  > Run `forge script script/DeployPlayToken.s.sol --rpc-url base-sepolia --sender <MY ADDRESS>` and show me the output.

  In my run, Foundry itself refused: `Error: script failed: Usage of address(this) detected in script contract.
  Script contracts are ephemeral and their addresses should not be relied upon.` So for this particular bug, Foundry
  is a third safety net. Don't count on a tool's safety net for every bug, though. That's why the next part adds a
  test.

**6c. Turn the bug into a test.** The bug is still in the file, so this test should fail:

**Prompt (plan mode):**
> Create test/DeployPlayToken.t.sol with `contract DeployPlayTokenTest is Test` and one test,
> test_ScriptMakesTheCallerOwner: deploy `new DeployPlayToken()`, call `script.run()` directly (no vm.prank, because
> Foundry doesn't allow pranks together with broadcasting), then assert `token.owner() == address(this)` with the
> message "owner must be the caller, not the script", and that address(this) holds `script.INITIAL_MINT()`.
> Don't change anything in src/ or script/. Run forge fmt, then forge test, and show me the output. I expect one
> test to fail. Don't fix it.

**You check:** you should see

```text
[FAIL: owner must be the caller, not the script: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f != 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496] test_ScriptMakesTheCallerOwner()
```

and `12 tests passed, 1 failed`. The first address is the owner the token actually got: the `DeployPlayToken`
contract your test deployed. The second is your test contract, the caller who should have been the owner. (In a
real `forge script` run, the owner would have been the script contract's simulated address, which never exists
on-chain.)

**6d. Fix it with git.** Your hand edit isn't tracked by rewind, so git restores it:

```text
!git restore script/DeployPlayToken.s.sol
!forge test
```

`13 tests passed, 0 failed`.

**Done when:** `!git status` shows only `test/DeployPlayToken.t.sol` as new, and `!git diff --stat script/` prints
nothing.

**Commit:** `Add a test that the deploy script makes the caller the owner`

---

## Step 7 — Secret scanning in CI, a pull request, and a merge (20 min)

**Learn.** Deny rules protect your secrets from Claude. **gitleaks** protects them from git: it scans every commit
for things that look like keys (API keys, private keys, tokens), using patterns and entropy (how random a string
looks). Two important facts:

- It scans **history**, not just the current files. Deleting a file with a key in it doesn't remove the key from
  history. Anyone who clones the repo can still find it.
- If a real key is ever pushed, the fix is to **rotate it** (make a new key, revoke the old one), not just to delete
  the commit. Assume someone copied it within seconds.

**Prompt (plan mode):**
> Add a second job called `secrets` to @.github/workflows/ci.yml, next to the existing `test` job. Give it
> `runs-on: ubuntu-latest`, `permissions: contents: read`, and `env: GITLEAKS_VERSION: 8.30.1`. Steps:
> 1. actions/checkout@v5 with `fetch-depth: 0` (full history) and `persist-credentials: false`
> 2. "Install gitleaks (checksum verified)": download `gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz` and
>    `gitleaks_${GITLEAKS_VERSION}_checksums.txt` from
>    `https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}` with `curl -sSfLO`, run
>    `sha256sum --check --ignore-missing` on the checksums file, then `tar -xzf` the archive, extracting only `gitleaks`
> 3. "Scan the whole git history for secrets": `./gitleaks git --redact --verbose .`
> Don't change the test job.

**You check:** open `.github/workflows/ci.yml`.
- `fetch-depth: 0` is there. Ask Claude: *"What would gitleaks miss with the default fetch-depth of 1?"*
- `--redact` is there. Ask: *"CI logs on a public repo are public. What does --redact protect?"*
- The checksum check comes **before** `tar`. Ask: *"What attack does checking the checksum stop, and what attack
  doesn't it stop?"* (It catches a corrupted or swapped download. It doesn't help if the attacker controls the
  release itself.)

Commit, then push the branch and open a pull request:

**Commit:** `Add gitleaks secret scanning to CI`

> Push the token branch to origin, then open a pull request into main with `gh pr create --fill`.

Wait for both CI jobs:

```text
!gh pr checks --watch
```

Both `test` and `secrets` should pass. (In my run, gitleaks found nothing in a clean repo, including Foundry's
`broadcast/` files, so it shouldn't give you false alarms.)

**Break it on purpose (5 min).** Prove the scanner catches a key. You'll use a **random number that was never a
wallet**, on a throwaway branch.

**🔑 Window B:**

```bash
git switch -c leak-test
printf 'DEPLOYER_PRIVATE_KEY=0x%s\n' "$(openssl rand -hex 32)" > leak-test.env
git add leak-test.env
git commit -m "Leak test: random fake key, delete this branch"
git push -u origin leak-test
gh run watch
```

The `secrets` job should **fail**, with `RuleID: generic-api-key`, `File: leak-test.env`, the secret shown as
`REDACTED`, and `leaks found: 1`. gitleaks scans **every branch** it can see, not just the one being tested (I
checked this locally), so while `leak-test` exists on GitHub, any other CI run would fail too. Clean up right away:

```bash
git switch token
git branch -D leak-test
git push origin --delete leak-test
```

Ask Claude in Window A: *"I deleted the leak-test branch. If that had been my real key, would it be safe now? What
should I do instead?"*

**Merge.** Deploy only code that was reviewed and merged, so the on-chain contract matches `main`:

> Merge the pull request with `gh pr merge --merge --delete-branch`, then switch to main and pull.

**Done when:** `!git log --oneline -1` on `main` shows the merge commit, and `!gh run list --branch main --limit 1`
shows success.

---

## Step 8 — 🔑 Window B: deploy and verify (20 min)

**Learn.**
- **`--account deployer`** tells Foundry to use your keystore. It asks for the password, signs, and forgets. That's
  why this runs in Window B: Claude Code's shell can't (and shouldn't) answer a password prompt.
- **`--verify`** submits your source code to Basescan right after the deployment. Basescan recompiles it with
  **exactly** the settings you pinned in `foundry.toml`, and compares the result to the bytecode on-chain.
  Constructor arguments are passed too, because they're appended to the deployment code. If everything matches, the
  contract page shows a green check and a readable "Contract" tab.
- **What verification proves:** this source code, with these settings, produces this bytecode. **What it doesn't
  prove:** that the code is safe, or that this is the "official" token. Anyone can deploy and verify a contract
  called PlayToken.

**Do it (Window B, in the project folder, on `main`):**

```bash
git switch main && git pull
export DEPLOYER=0xYourAddressHere
forge script script/DeployPlayToken.s.sol:DeployPlayToken \
  --rpc-url base-sepolia \
  --account deployer \
  --sender $DEPLOYER \
  --broadcast \
  --verify
```

Enter your keystore password when asked (use `winpty` in front if the prompt doesn't work, as in Step 2).

**You check:** in the output, find:
- `PlayToken deployed at 0x...` and `Owner 0x...`, which must equal `$DEPLOYER`. Copy the token address:

  ```bash
  export TOKEN=0xTheTokenAddress
  ```

- `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.`
- Then the verification part, something like `Start verifying contract 0x... deployed on base-sepolia`, and finally a
  success line such as `Contract successfully verified`. It can take a minute, and Foundry retries on its own while
  Basescan indexes the new contract.

Now open `https://sepolia.basescan.org/address/<TOKEN>` in your browser:
- The **Contract** tab has a green check and shows `PlayToken.sol` and the OpenZeppelin files.
- **Read Contract** shows `name` = PlayToken, `MAX_SUPPLY` = 1000000000000000000000000, and `owner` = your address.
- Click the creation transaction and find the "From" address (yours) and the gas used.

> ⚠️ **If verification fails:**
> - **`Free API access is not supported for this chain`**: Etherscan says verification stays free on all chains,
>   but if your key is refused anyway, verify on **Blockscout**, an open-source explorer for Base Sepolia that needs
>   no key. The constructor arguments are your address and 10,000 tokens, ABI-encoded:
>
>   ```bash
>   forge verify-contract $TOKEN src/PlayToken.sol:PlayToken \
>     --chain base-sepolia \
>     --verifier blockscout \
>     --verifier-url https://base-sepolia.blockscout.com/api/ \
>     --constructor-args $(cast abi-encode "constructor(address,uint256)" $DEPLOYER 10000000000000000000000) \
>     --watch
>   ```
>
>   Then check `https://base-sepolia.blockscout.com/address/<TOKEN>`.
> - **Timeout or "not found"**: the explorer hadn't indexed the contract yet. Run the same `forge verify-contract`
>   command without the three `--verifier` lines (it then uses Etherscan and your `.env` key).
> - **`Bytecode does not match`**: your compiler settings changed between deploy and verify. That's exactly why
>   Step 0 pinned them. Ask Claude in Window A to compare `foundry.toml` with the settings on the explorer page.

**Done when:** the Basescan page shows the contract as verified (or the Blockscout page does, if you used the
fallback), and `owner` is your address.

**Commit (in Window A):**

> Commit the new files under broadcast/ with the message below. Show me `git status` first.

**Commit:** `Record PlayToken deployment on Base Sepolia`

Ask Claude: *"Look at broadcast/DeployPlayToken.s.sol/84532/run-latest.json. Is there anything secret in it?"* (There
shouldn't be: addresses, hashes, bytecode and gas. The RPC URL went to `cache/`.)

---

## Step 9 — 🔑 Window B: use your token on-chain, and check the bytecode yourself (10 min)

**Read the state** (reading is free and needs no key):

```bash
cast call $TOKEN "name()(string)" --rpc-url base-sepolia
cast call $TOKEN "owner()(address)" --rpc-url base-sepolia
cast call $TOKEN "balanceOf(address)(uint256)" $DEPLOYER --rpc-url base-sepolia
```

You should see `"PlayToken"`, your address, and `10000000000000000000000 [1e22]` (10,000 tokens with 18 decimals).

**Claim from your faucet** (this sends a transaction, so it asks for your password):

```bash
cast send $TOKEN "claim()" --account deployer --rpc-url base-sepolia
cast call $TOKEN "balanceOf(address)(uint256)" $DEPLOYER --rpc-url base-sepolia
```

The first command prints a receipt with `status 1 (success)` and two logs: OpenZeppelin's `Transfer` from the zero
address (a mint), and your `Claimed`. The balance is now `10100000000000000000000 [1.01e22]`. Find the transaction on
Basescan and open its **Logs** tab.

**Claim again right away:**

```bash
cast send $TOKEN "claim()" --account deployer --rpc-url base-sepolia
```

It fails **before** sending anything, during gas estimation, with `custom error 0x854f3dd0` and, in my run, the
decoded `ClaimTooSoon(...)` with a Unix timestamp. That number is exactly one day after your first claim. Nothing was
sent, so no gas was spent. (If yours shows only the hex, decode it: `cast decode-error <the 0x854f3dd0... data>
--sig "ClaimTooSoon(uint256)"`.)

**Check the bytecode yourself.** Verification is something you can do without trusting Basescan:

```bash
cast keccak $(cast code $TOKEN --rpc-url base-sepolia)
cast keccak $(forge inspect PlayToken deployedBytecode)
```

The two hashes should be **identical**. The first is the code on-chain; the second is what your local compiler
produces from `main`. In my local run, they matched exactly.

**You check (Window A):** ask Claude: *"My on-chain bytecode hash equals forge inspect's deployedBytecode hash. Why
would they differ if PlayToken had an immutable variable, or if I compiled with a different optimizer setting? How do
explorers handle the immutable case?"*

**Done when:** your balance shows the claim, the second claim was refused with `ClaimTooSoon`, and the two hashes
match.

**Commit:** nothing new.

---

## Step 10 — README, INTERVIEW.md, push, green CI (15 min)

**Prompt 1 (README):**
> Update @README.md. Add a "Deployment" section near the top with: network Base Sepolia (chain ID 84532), the token
> address <TOKEN> linked to https://sepolia.basescan.org/address/<TOKEN>, the owner <DEPLOYER>, that the source is
> verified, and how to claim with `cast send <TOKEN> "claim()" --account <name> --rpc-url base-sepolia`.
> Replace the "Design decisions" TODO with short bullets on: one internal _mintCapped function for every mint path,
> the per-address cooldown versus the cap as the real protection, why compiler and EVM version are pinned, the
> Foundry keystore instead of a private key in .env, two terminal windows (Claude never handles the key or the
> password), the .claude/settings.json deny rules and what they don't cover, gitleaks scanning full history in CI,
> and deploying only from reviewed, merged main.
> Replace the "Known limitations" TODO with: the faucet is sybil-able (new addresses get new claims), the owner can
> mint up to the cap and ownership is single-step (OpenZeppelin's Ownable2Step would add an accept step), the
> deployer key is a hot key (production would use a hardware wallet or a KMS, and hand ownership to a multisig or
> my timelock), deny rules are best-effort without the sandbox, and Base Sepolia is a testnet that will be retired
> one day. Also add these reviewer findings I decided not to fix: <paste your scratch note here, or delete this>.
> Don't touch the "How I used Claude Code" section.

**Prompt 2 (INTERVIEW.md):**
> Fill in @INTERVIEW.md with these 5 questions and short model answers (5–8 sentences each), based on this code:
> 1. What exactly does "verified on Basescan" prove, and what doesn't it prove? Walk through what the explorer
>    recompiles and compares, and why compiler settings and constructor arguments matter.
> 2. How did I keep the deployer key safe in this project, and what would I change for a production stablecoin
>    deployment? Cover the keystore, the two windows, deny rules and their limits, gitleaks, hardware wallets or KMS,
>    and moving ownership to a multisig or timelock.
> 3. My token has a public faucet with a per-address daily cooldown. How would an attacker drain it, what actually
>    protects the supply, and how do real faucets resist sybil attacks (use the Alchemy mainnet-balance rule)?
> 4. A deploy script used address(this) as the token owner and all 12 contract tests stayed green. What would have
>    happened on-chain, why did the tests miss it, and which three things caught it in my project?
> 5. Give a checklist for moving this deployment from testnet to mainnet, including chain ID, EVM version, gas,
>    verification, ownership, monitoring, and what's different about keys and permissions.

**You check:** read every answer, and rewrite at least one in your own words. For Q1, the answer must say that
verification proves a source-to-bytecode match, not safety or authenticity. For Q4, the three things are the
`/code-review` run (if it caught it), Foundry's `address(this)` guard in simulation, and the new script test.

**Write "How I used Claude Code" yourself** in `README.md`: what the three probes did in Step 1 (and whether the
canary leaked), what `/code-review` found on the real branch, whether it caught the planted `address(this)` bug,
and one finding you checked by hand.

**Done when:**

```bash
forge fmt --check && forge build && forge test -vv
```

all pass with `13 tests passed, 0 failed`. Then commit and push (Claude will ask before `git push`):

**Commit:** `Add deployment details, design notes and interview Q&A`

Then check CI:

```text
!gh run list --branch main --limit 1
```

Wait until the newest run shows success. Both jobs, `test` and `secrets`, must pass. If one fails, open it with
`!gh run view <id> --log-failed`, then ask Claude to fix it.

**Optional (2 min): protect every project.** Copy the deny rules into your user settings, `~/.claude/settings.json`,
so they apply in every repo. Merge them into the existing `permissions.deny` array by hand, the same way you merged
your kit's rules on Day 0. Don't replace the file.

---

## When you're done

Tell the roadmap chat **"done"**. It will review the repo, run the tests, check your contract on Basescan, and tick
this row in the roadmap. Keep `$TOKEN` handy: Week 2's dApp uses it.

## Level up

**Keep secrets out of Claude's reach by design, then use rules as a seatbelt.** A deny list is an enumeration, and
there's always another command, alias or script, so rules can't be your only protection. Arrange things so the
valuable secret never exists where Claude could read it: an encrypted keystore, a second terminal for passwords, a
`.env` that holds only cheap, revocable keys. Then add deny rules for the common accidents, test them with a canary
(never with a real secret), and scan git history in CI for whatever slips through. The same thinking applies to
reviews: run `/code-review` **before** an irreversible step, on a branch, so the diff it sees is exactly what you're
about to ship.
