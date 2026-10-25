# Cost comparison: self-hosted (this AMI) vs. GitHub-hosted runners

**The headline point**: GitHub does not bill Actions minutes for self-hosted runners at
all, regardless of repository visibility. For a private repo on GitHub-hosted runners,
every minute is billed; for public repos, GitHub-hosted is free. The real comparison is
therefore: *GitHub's per-minute price (private repos only) vs. your own EC2 compute
cost (every repo, public or private)*.

Prices below are illustrative, using on-demand/Spot list prices in `us-east-1` at the
time of writing. **Check current prices before budgeting**: GitHub's
[Actions billing docs](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions)
and the [AWS EC2 on-demand pricing page](https://aws.amazon.com/ec2/pricing/on-demand/)
are the sources of truth; both change over time.

## Per-minute compute cost

| Runner                                          | vCPU / RAM  | $/hour (approx.) | $/minute (approx.) |
| -------------------------------------------------- | ----------- | ----------------- | -------------------- |
| GitHub-hosted `ubuntu-latest` (2-core)             | 2 / 7 GB    | -                  | $0.008 (private repos only; free for public repos) |
| Self-hosted, `t3.medium` on-demand                 | 2 / 4 GB    | ~$0.0416           | ~$0.0007              |
| Self-hosted, `m6i.large` on-demand                 | 2 / 8 GB    | ~$0.096             | ~$0.0016              |
| Self-hosted, `m6i.large` Spot (~70% off, varies)   | 2 / 8 GB    | ~$0.029             | ~$0.0005              |
| Self-hosted, `m6g.large` (Graviton) on-demand      | 2 / 8 GB    | ~$0.077             | ~$0.0013              |
| Self-hosted, `m6g.large` (Graviton) Spot           | 2 / 8 GB    | ~$0.023             | ~$0.0004              |

At list on-demand prices, a comparably-sized self-hosted runner costs roughly
**4-5x less per minute** than GitHub-hosted for private repos; with Spot and Graviton
it's closer to **15-20x less**. For public repos, GitHub-hosted is already free, so the
comparison becomes "do I need self-hosted for non-cost reasons" (see below).

## What's *not* captured in the per-minute number

- **Boot + registration overhead.** Each ephemeral job pays for roughly 30-90 seconds of
  instance boot, cloud-init, and runner registration before the job itself starts. At
  ~$0.0016/min (`m6i.large` on-demand), one extra minute of overhead per job costs about
  $0.0016 - small, but it adds up at high job volume and should be included when you
  estimate total spend (`job duration + ~1 min` x per-minute rate, not just job
  duration).
- **EBS storage.** The root volume (default 30 GiB gp3) is billed while an instance
  exists, which for ephemeral runners is only the job's lifetime - a rounding error per
  job, but non-zero at scale.
- **Data transfer.** Pulling container images, npm/pip/Go module caches, and the Trivy
  vulnerability DB on every single ephemeral boot can dominate cost and job latency at
  high volume if nothing is cached. Mitigate with a VPC endpoint + S3-backed cache
  action, a pull-through container registry cache, or a warm pool (fixed `min_size`)
  instead of pure scale-from-zero.
- **The scale-out Lambda/webhook.** Typically a few cents a month at normal volume -
  negligible, but it's real infrastructure you now own and must keep running (see
  [docs/architecture.md](architecture.md#scale-out-guidance)).
- **Your time.** Self-hosted runners mean *you* patch the AMI (this repo's weekly
  rebuild helps), manage IAM, and debug registration issues. GitHub-hosted runners have
  none of that operational surface. This is real cost; it just isn't a line item.

## When self-hosted (this AMI) tends to win

- High job volume on **private repos**, where GitHub's per-minute billing adds up fast.
- Jobs that need **more CPU/RAM/disk** than GitHub-hosted tiers offer, or need
  **Graviton/arm64** specifically.
- Jobs that need **network access to private VPC resources** (internal package
  registries, databases, internal APIs) that GitHub-hosted runners can't reach.
- Workloads that benefit from **Spot pricing** and can tolerate occasional preemption
  (ephemeral, single-job runners are a great fit for Spot - a reclaimed Spot instance
  just means one job retries on a fresh runner).

## When GitHub-hosted still makes more sense

- **Public repositories** - GitHub-hosted is free; self-hosted only adds cost and
  operational burden.
- **Low, bursty job volume**, where the Lambda/webhook/IAM setup cost (in engineering
  time) outweighs the savings.
- Teams that don't want to own patching, IAM, or AMI-rebuild cadence at all, and would
  rather pay GitHub's per-minute rate for zero operational surface.
