# audit-dojo

This is my personal audit log. I review smart contracts, find bugs, write reports, and occasionally yell at `msg.sender`.

It’s not a company thing. Not a bounty farming repo. Just me, sharpening my skills and documenting the journey. Think of it like a sword training diary, if swords were EVM bytecode and I had insomnia.


## What's inside

Each folder = one protocol I looked at.  
I just audit because it's fun breaking things that are supposed to work.


## Finished so far

| Protocol       | Type           | Date       | Notes |
|----------------|----------------|------------|-------|
| [PasswordStore](./2025-07-29-PasswordStore-audit.pdf)  | Shadow Audit   | Jul 2025   | Stored passwords on-chain. Classic. |
| [PuppyRaffle](./2025-08-31-PuppyRaffle-audit.pdf)    | First Flight | Aug 2025   | Lottery of puppies, but randomness was rigged from the start. |

## Tools I actually use

- [**Foundry**](https://getfoundry.sh/) – for building, testing, yelling at invariants
- **Slither**  – for static analysis (aka letting a robot read the code first)
- [**Aderyn**](https://github.com/Cyfrin/aderyn) – from Cyfrin, for basic hygiene
- **LaTeX (eisvogel)** – for nice PDFs when I’m pretending to be professional



## Why this exists

I’m aiming to be a top 1% smart contract auditor.  
That doesn’t happen by copying other people’s reports.  
It happens by writing your own, debugging your logic, and documenting what you learned — every time.

This is that.


## Contact

If you're a dev or a protocol and want eyes on your contracts, open an issue or find me [@samuraiigintoki](https://x.com/samuraiigintoki).  
No weird corporate pitches, please. I already ignore my emails.

---

## License

MIT.  
Use the reports, steal the ideas, fork the structure — just do your own analysis.  
Copying won’t help you survive a real audit.


