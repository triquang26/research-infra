# Case Study — Ctrl-World: thao tác tay từng bước

> **Paper**: Guo et al. 2026, *Ctrl-World: A Controllable Generative World Model for Robot Manipulation*. ICLR 2026, arXiv:2510.10125. Project: https://ctrl-world.github.io
>
> **Mục tiêu**: dùng 9 skill `/exp-*` (vừa build) để document một research thread reproduce + ablation paper này. 11 node, 4–5 hop sâu, có pass/fail giả lập, có cross-link.
>
> **Repo dùng để test**: `/tmp/ctrl-world-exp` (đã thực sự build xong với output bên dưới — không phải synthetic).

---

## 0. Setup repo (1 lần)

```
$ mkdir -p /tmp/ctrl-world-exp && cd /tmp/ctrl-world-exp
$ git init -b main
$ git config user.email researcher@local && git config user.name Researcher
$ echo "# Ctrl-World Reproduction & Ablation" >README.md
$ mkdir -p src && touch src/.gitkeep
$ git add . && git commit -m "initial: project scaffold"
```

Bắt đầu Claude Code trong `/tmp/ctrl-world-exp`. Gõ:

### Thao tác 0.1 — `/exp-init`

**User**:
```
/exp-init
```

**Claude (Inspect)**: chạy bash block trong skill, in:
```
PWD: /tmp/ctrl-world-exp
REPO_ROOT: /tmp/ctrl-world-exp
Status: clean to init.
```

**Claude (Preview)**:
> Will bootstrap a vault at `/tmp/ctrl-world-exp/.experiments/`:
> - `.experiments/.git/` — nested git repo (vault có history riêng)
> - `.experiments/nodes/` (rỗng; mỗi experiment 1 file markdown)
> - `.experiments/attachments/` (rỗng; plots/csv)
> - `.experiments/INDEX.md` (tự maintain root list)
> - `.experiments/.obsidian/app.json` (graph-view defaults)
> - `.experiments/.gitignore` (exclude Obsidian workspace state)
>
> Và trong outer repo: append `.experiments/` vào `.gitignore`.

**User**: `y`

**Claude (Execute)**: chạy mkdir, viết các file, `git init` trong `.experiments/`, commit bên trong vault, append `.experiments/` vào outer `.gitignore` rồi commit outer.

**Report**:
- Vault: `/tmp/ctrl-world-exp/.experiments/`
- Vault HEAD: `78f6cba experiments: bootstrap vault`
- Outer HEAD: `… experiments: gitignore .experiments/`
- Next: `/exp-new "<first hypothesis>"`

---

## 1. Hop 0 — Root node: reproduce paper

### Thao tác 1.1 — `/exp-new`

**User**:
```
/exp-new "Reproduce Ctrl-World on DROID: 20s coherent rollouts and +44.7% pi-0.5-DROID success" --slug=ctrl-world-reproduce --with-branch
```

**Claude (Inspect)**:
```
VAULT=/tmp/ctrl-world-exp/.experiments
CUR_BRANCH=main
ID=a87147   (gen)
```

**Claude (Preview)**:
```
About to create root node:
  id:         a87147
  slug:       ctrl-world-reproduce
  file:       .experiments/nodes/2026-05-a87147-ctrl-world-reproduce.md
  status:     active
  branch:     exp/a87147-ctrl-world-reproduce (from main)
  commit msg: "exp(a87147): new root — ctrl-world-reproduce"

Hypothesis:
  Reproduce Ctrl-World on DROID: 20s coherent rollouts and +44.7% pi-0.5-DROID success.
```

**User**: `y`

**Claude (Execute)**: tạo branch, checkout, render node template ra file, update INDEX.md, commit trong vault repo.

**Report**:
- File: `.experiments/nodes/2026-05-a87147-ctrl-world-reproduce.md`
- Branch: `exp/a87147-ctrl-world-reproduce` (HEAD)
- Vault commit: `aef06b3`
- Suggested next: chạy thực nghiệm, rồi `/exp-record`.

### Thao tác 1.2 — chạy thực nghiệm xong, ghi kết quả

**User** (sau khi train xong):
```
/exp-record coherent_seconds=18.5 policy_uplift_pct=41.2
```

**Claude (Inspect)**: detect current branch → current node là `a87147`. Đọc node, thấy `## Method`, `## Results`, `## Conclusion` vẫn placeholder.

**Claude (Ask)**: "Method và Conclusion bạn viết hay tôi propose từ metrics?"

**User**: "Method tôi viết: 'Train Ctrl-World on DROID (95k traj). 1.5B SVD backbone. 3-view + k=4 memory + action cond.' Conclusion: 'Reproduction PASS. Anchor for ablations.'"

**Claude (Preview)**:
```
About to update a87147:
  frontmatter:
    metrics: {coherent_seconds: 18.5, policy_uplift_pct: 41.2}
    status: active → completed
    date-completed: 2026-05-27
  body:
    ## Method ← (user-provided text)
    ## Results ← bullets from metrics
    ## Conclusion ← (user-provided text)
  commit msg: "exp(a87147): record results — ctrl-world-reproduce"
```

**User**: `y`. **Vault commit**: `7c1b44b`.

> 📌 **Status**: PASS (gần paper claim).

---

## 2. Hop 1 — 4 ablation branches

Bốn ablation siblings, mỗi cái là 1 lần `/exp-branch` từ root.

### Thao tác 2.1 — Ablate memory retrieval

**User** (đang ở branch `exp/a87147-...`):
```
/exp-branch "Bỏ memory (k=0). Expect FAIL." --slug=ablate-memory-k0 --with-branch
```

Claude:
- Inspect → parent = current node `a87147`, parent_branch = `exp/a87147-ctrl-world-reproduce`
- Preview: child id `6557a5`, slug `ablate-memory-k0`, parent `[[2026-05-a87147-ctrl-world-reproduce]]`, branch `exp/6557a5-ablate-memory-k0` from `exp/a87147-ctrl-world-reproduce`
- User confirm `y`
- Execute → file + branch + vault commit `b1079e1`

Sau train: `/exp-record coherent_seconds=5.8 policy_uplift_pct=12.3` + method/conclusion → **FAIL** (drift sau 6s). Vault commit `b2c7258`.

### Thao tác 2.2 — Ablate wrist cam

**User** (chuyển về root branch để branch tiếp):
```
git checkout exp/a87147-ctrl-world-reproduce
/exp-branch "Bỏ wrist cam, chỉ 2 third-person" --slug=ablate-wristcam --with-branch
```

→ child `1a53bf`. Sau train: `coherent=12.4, uplift=22.1, hallucination=4.2/min` (baseline 0.8). **FAIL**.

### Thao tác 2.3 — Ablate action conditioning

```
git checkout exp/a87147-ctrl-world-reproduce
/exp-branch "Bỏ frame-level action, chỉ language" --slug=ablate-action-cond --with-branch
```

→ child `e894a2`. Sau train: `coherent=16.2` (gần baseline về thời lượng!) nhưng `uplift=8.9, iou=0.31` (vs 0.78 baseline). **FAIL** — coherent mà ko follow action ⇒ vô dụng.

### Thao tác 2.4 — Scale down data (10k)

```
git checkout exp/a87147-ctrl-world-reproduce
/exp-branch "10k trajectories thay 95k" --slug=scale-down-10k --with-branch
```

→ child `491227`. Sau train: `coherent=16.8, uplift=36.4`. **PASS** gần baseline với 1/10 data.

---

## 3. Hop 2 — recovery + threshold search

### Thao tác 3.1 — Recover from memory ablation

Từ N1A (FAIL) — không nên dừng, nên thử k cao hơn xem có monotonic không.

**User**:
```
git checkout exp/6557a5-ablate-memory-k0
/exp-branch "k=8 (double). Expect vượt baseline." --slug=memory-k8 --with-branch
```

→ child `762f59`. Train: `coherent=22.1 (+3.6 vs baseline)`, `uplift=43.0 (+1.8)`. **PASS**. Memory monotonic.

### Thao tác 3.2 — Recover from wristcam ablation

```
git checkout exp/1a53bf-ablate-wristcam
/exp-branch "Front+wrist, bỏ side" --slug=two-cam-front-wrist --with-branch
```

→ `be6a2c`. `coherent=17.2 (-1.3), uplift=38.7 (-2.5), hallucination=1.1/min`. **PARTIAL PASS**.

### Thao tác 3.3 — Threshold search dưới 10k

```
git checkout exp/491227-scale-down-10k
/exp-branch "1k trajectories" --slug=scale-down-1k --with-branch
```

→ `7357ac`. `coherent=9.4, uplift=11.2`. **FAIL**. Threshold ở đâu giữa 1k và 10k?

---

## 4. Hop 3 — Pareto refinement + threshold pinpoint

### Thao tác 4.1 — k=8 + lowres để bù compute

```
git checkout exp/762f59-memory-k8
/exp-branch "k=8 + res 256-192" --slug=memory-k8-lowres --with-branch
```

→ `08d04b`. `coherent=21.4 (-0.7), uplift=42.1, gpu_hours=142 (-15%)`. **PASS — Pareto win**.

### Thao tác 4.2 — 5k threshold

```
git checkout exp/7357ac-scale-down-1k
/exp-branch "5k threshold search" --slug=scale-down-5k --with-branch
```

→ `1c09f7`. `coherent=15.9, uplift=33.8, train 4x faster`. **PASS**. 5k đủ cho 80% performance ở 1/20 compute.

---

## 5. Hop 4 — stress test

### Thao tác 5.1 — Edge cases

```
git checkout exp/08d04b-memory-k8-lowres
/exp-branch "Stress test 12-cam + low-light" --slug=edge-cases-12cam --with-branch
```

→ `9fe87c`. `coherent_edge=8.2 (massive drop)`, `hallucination=5.1/min`. **FAIL on edge**. Model overfit to 3-view normal scenes.

---

## 6. Cross-links

Sau khi đã chạy hết, user nhận ra 3 mối quan hệ phi-parent:

### Link 1 — N2A `extends` N1A (recovery)

`memory-k8` (PASS) là sự nối tiếp logic của `ablate-memory-k0` (FAIL): cùng trục biến k, một bên k=0 (fail), một bên k=8 (vượt baseline).

**User** (về main):
```
git checkout main
/exp-link 762f59 6557a5 extends
```

Claude:
- Preview: thêm vào `links` của cả 2 file
- User `y`
- Vault commit: `59763cb exp: link extends 762f59 ↔ 6557a5`

### Link 2 — N3D `contradicts` N0 (paper claim sai về scale)

5k traj đủ cho ~80% performance ⇒ paper claim "95k necessary" overkill.

```
/exp-link 1c09f7 a87147 contradicts
```

→ Vault commit: `29e2ea0`.

### Link 3 — N3A `replicates` N2A (cùng đi đến cùng kết luận về memory)

Cả 2 confirm "k=8 > k=4 monotonically". N3A thêm bằng chứng dưới constraint compute thấp hơn.

```
/exp-link 08d04b 762f59 replicates
```

→ Vault commit: `9ae907d`.

---

## 7. Trạng thái cuối — graph 11 node, 5 hop, 3 cross-link

### 7.1 ASCII tree

```
ROOT (hop 0)
└── a87147 ctrl-world-reproduce            [PASS  coh=18.5 uplift=41.2]
    ├── 6557a5 ablate-memory-k0            [FAIL  coh=5.8  uplift=12.3]
    │   └── 762f59 memory-k8               [PASS  coh=22.1 uplift=43.0]  ──extends──> 6557a5
    │       └── 08d04b memory-k8-lowres    [PASS  coh=21.4 uplift=42.1]  ──replicates──> 762f59
    │           └── 9fe87c edge-cases-12cam [FAIL  coh=8.2  halluc=5.1]
    ├── 1a53bf ablate-wristcam             [FAIL  coh=12.4 halluc=4.2]
    │   └── be6a2c two-cam-front-wrist     [PARTIAL coh=17.2 halluc=1.1]
    ├── e894a2 ablate-action-cond          [FAIL  coh=16.2 iou=0.31]
    └── 491227 scale-down-10k              [PASS  coh=16.8 uplift=36.4]
        └── 7357ac scale-down-1k           [FAIL  coh=9.4  uplift=11.2]
            └── 1c09f7 scale-down-5k       [PASS  coh=15.9 uplift=33.8]  ──contradicts──> a87147

Hops: 0 (root) → 1 (4 ablations) → 2 (3 recoveries) → 3 (2 refinements) → 4 (1 stress test)
                                                          ↑ Pareto win + threshold pinpoint
```

### 7.2 Outer git branches (12 total)

```
* main
  exp/08d04b-memory-k8-lowres
  exp/1a53bf-ablate-wristcam
  exp/1c09f7-scale-down-5k
  exp/491227-scale-down-10k
  exp/6557a5-ablate-memory-k0
  exp/7357ac-scale-down-1k
  exp/762f59-memory-k8
  exp/9fe87c-edge-cases-12cam
  exp/a87147-ctrl-world-reproduce
  exp/be6a2c-two-cam-front-wrist
  exp/e894a2-ablate-action-cond
```

Outer `git log` chỉ có 3 commits: `initial`, `experiments: gitignore .experiments/`. Vault commit không ô nhiễm code branches.

### 7.3 Vault git log (26 commits)

```
9ae907d exp: link replicates 08d04b ↔ 762f59
29e2ea0 exp: link contradicts 1c09f7 ↔ a87147
59763cb exp: link extends 762f59 ↔ 6557a5
6c14e6c exp(9fe87c): record results — edge-cases-12cam
00224f0 exp(9fe87c): branch — edge-cases-12cam
1a3f9ea exp(1c09f7): record results — scale-down-5k
5ae72a2 exp(1c09f7): branch — scale-down-5k
5d7ed6b exp(08d04b): record results — memory-k8-lowres
f23c80a exp(08d04b): branch — memory-k8-lowres
67a23f3 exp(7357ac): record results — scale-down-1k
ca3b70a exp(7357ac): branch — scale-down-1k
5ddd488 exp(be6a2c): record results — two-cam-front-wrist
437730f exp(be6a2c): branch — two-cam-front-wrist
024222a exp(762f59): record results — memory-k8
391447a exp(762f59): branch — memory-k8
ff0bd63 exp(491227): record results — scale-down-10k
48f7e27 exp(491227): branch — scale-down-10k
b80c7a5 exp(e894a2): record results — ablate-action-cond
7db59aa exp(e894a2): branch — ablate-action-cond
457fce8 exp(1a53bf): record results — ablate-wristcam
56cec8c exp(1a53bf): branch — ablate-wristcam
b2c7258 exp(6557a5): record results — ablate-memory-k0
b1079e1 exp(6557a5): branch — ablate-memory-k0
7c1b44b exp(a87147): record results — ctrl-world-reproduce
aef06b3 exp(a87147): new root — ctrl-world-reproduce
78f6cba experiments: bootstrap vault
```

Đọc từ dưới lên = đúng thứ tự thời gian thực sự thao tác.

### 7.4 INDEX.md (mở vault trong Obsidian thì đây là entry)

```
# Experiments — Index

## Roots

<!-- ROOTS_START -->
- [[2026-05-a87147-ctrl-world-reproduce]] — ctrl-world-reproduce
<!-- ROOTS_END -->
```

Chỉ 1 root vì tất cả branch out từ N0. Obsidian graph view sẽ render tree đầy đủ từ wikilinks.

### 7.5 Node ví dụ: hop-3 Pareto win (`memory-k8-lowres`)

```yaml
---
id: 08d04b
slug: memory-k8-lowres
type: experiment
status: completed
hypothesis: 'k=8 + res 256-192.'
parents:
- '[[2026-05-762f59-memory-k8]]'
links:
- to: '[[2026-05-762f59-memory-k8]]'
  relation: replicates
github-branch: exp/08d04b-memory-k8-lowres
date-created: 2026-05-27
date-completed: 2026-05-27
metrics:
  coherent_seconds: 21.4
  policy_uplift_pct: 42.1
  gpu_hours: 142
---

# 08d04b — memory-k8-lowres

## Method
k=8, res 192x192.

## Results
- coherent 21.4 (-0.7), uplift 42.1, compute -15%

## Conclusion
PASS. Pareto.
```

---

## 8. Quan sát quy trình

### Cái gì WORK tốt
1. **Atomic commits**: mỗi `/exp-record` = 1 commit, `git log` đọc như tường thuật quá trình nghĩ.
2. **Vault tách khỏi code branches**: 11 outer branch tha hồ rebase/merge code mà không ảnh hưởng vault history. Cross-branch ops (link, compare) thấy hết mọi node vì vault là 1 nguồn duy nhất.
3. **Branch git ↔ node 1-1**: từ branch tên `exp/08d04b-memory-k8-lowres`, biết ngay node tương ứng. `git checkout exp/08d04b-…` = đi đến code của node đó. Đảo lại, từ node frontmatter `github-branch` biết ngay phải checkout cái nào.
4. **HITL 4-step**: mọi op state-changing đều có Preview → Confirm, không bao giờ đoán slug hay hypothesis wording. Nếu chán confirm có thể auto-mode về sau.
5. **5 hop sâu trong 1 buổi**: vì mỗi atomic op chỉ ~30s overhead (gõ + confirm), 11 node = 11 lần `/exp-branch` + 11 `/exp-record` + 3 `/exp-link` ≈ 25 cycle. Nhanh hơn nhiều so với viết folder thủ công.

### Cái gì gãi đầu (TODO v2)
1. **Hypothesis trong frontmatter bị YAML re-serialize**: `hypothesis: 'text...\n\n  '` xấu vì `yaml.dump` không giữ literal block scalar. Workaround: chỉnh tay, hoặc tweak `fm.py` dùng custom representer.
2. **Outer branches nhiều**: 11 exp branches cùng trong main repo, sau 50 node sẽ rối. Cần `/exp-archive` để move/delete khi node hoàn thành lâu rồi.
3. **Không có `/exp-status` hay `/exp-compare` chạy thật trong demo này** (chỉ build, chưa demo display). Sẽ thấy giá trị khi vault có >20 node.
4. **INDEX chỉ list roots**: hop ≥1 không tự nhiên thấy được nếu không mở Obsidian. `/exp-status [node-id]` lấp khoảng đó nhưng cần invoke từng node.
5. **`/exp-plan`**: chưa demo. Sẽ rất hay khi bí ý — Claude propose 2-3 hypothesis con dựa trên metrics của node hiện tại.

### Sau 4–5 hop graph trông thế nào
- **Bề rộng**: 1 root → 4 hop-1 → 3 hop-2 → 2 hop-3 → 1 hop-4. Hình "cây giảm bề rộng" — siblings dần ít đi vì mỗi hop là 1 lựa chọn cụ thể hơn.
- **Bề sâu**: nhánh hứa hẹn nhất (memory ablation → recovery → Pareto → stress test) đi sâu 4 hop. Các nhánh khác (action-cond, wristcam) chỉ 1-2 hop vì sớm xác định ngõ cụt.
- **Cross-links**: tạo ra "ngắn mạch" giúp navigate từ kết quả mới ngược về paper claim cũ ngay (vd N3D contradicts N0). Trong Obsidian graph view, các cross-link làm graph nhìn có "feedback loop", phản ánh đúng quá trình suy nghĩ.

---

## 9. Reproduce demo này

```bash
# Skills đã symlink ~/.claude/skills/exp-* vào /Users/twang/HCMUT/Research/ObsidianGraph/skills/.
# Chạy lại toàn flow tự động:
bash -c "$(curl -s https://example.invalid/build-ctrl-world-graph.sh)"  # fictional URL

# Hoặc thủ công: dùng skills /exp-* trực tiếp trong claude code,
# theo đúng 25 thao tác mô tả ở Section 1-6.
```

Repo build sẵn: `/tmp/ctrl-world-exp/`.
Vault: `/tmp/ctrl-world-exp/.experiments/` — mở bằng Obsidian để xem graph view.
