// gen-board-canvas.mjs — 从 specs/board/*.json 聚合生成 board.canvas.tsx
// 用法：node scripts/gen-board-canvas.mjs
// 多 agent 并行：每个 agent 只改自己的 specs/board/NNN-功能名.json，不碰别人的
// agent 更新任务文件后跑此脚本，Canvas 自动反映所有任务最新状态

import { readFileSync, writeFileSync, readdirSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const boardDir = join(process.cwd(), "specs", "board");
const canvasDir = join(homedir(), ".cursor", "projects", "d", "canvases");
const canvasFile = join(canvasDir, "board.canvas.tsx");

// 读阶段配置
const stages = JSON.parse(readFileSync(join(boardDir, "_stages.json"), "utf8"));

// 读所有任务文件（排除 _ 开头的配置文件）
const taskFiles = readdirSync(boardDir).filter(f => f.endsWith(".json") && !f.startsWith("_"));
const tasks = taskFiles.map(f => JSON.parse(readFileSync(join(boardDir, f), "utf8")));

// 聚合 changelog（按时间倒序）
const changelog = tasks
  .flatMap(t => (t.changelog || []).map(c => ({ ...c, taskId: t.id })))
  .sort((a, b) => b.time.localeCompare(a.time));

const stagesJson = JSON.stringify(stages);
const tasksJson = JSON.stringify(tasks.map(t => ({ id: t.id, name: t.name, stage: t.stage, role: t.role, progress: t.progress, updatedAt: t.updatedAt, keyChanges: t.keyChanges })));
const changelogJson = JSON.stringify(changelog.slice(0, 20));

const canvasCode = `import { Card, CardHeader, CardBody, Grid, Row, Stack, H1, H2, H3, Text, Pill, Stat, Table, useHostTheme } from "cursor/canvas";

const STAGES = ${stagesJson};
const tasks = ${tasksJson};
const changelog = ${changelogJson};

function stageLabel(s: string) { return STAGES.find((x: any) => x.key === s)?.label ?? s; }

function TaskCard({ task }: { task: any }) {
  return (
    <Card>
      <CardHeader trailing={<Pill size="sm" active>{task.progress}%</Pill>}>
        {task.name}
      </CardHeader>
      <CardBody>
        <Stack gap={8}>
          <Text size="small" tone="tertiary">#{task.id} · {stageLabel(task.stage)} · {task.role}</Text>
          <Text size="small" tone="secondary">{task.keyChanges[0] ?? "—"}</Text>
        </Stack>
      </CardBody>
    </Card>
  );
}

function StageColumn({ stage }: { stage: any }) {
  const items = tasks.filter((t: any) => t.stage === stage.key);
  return (
    <Stack gap={8}>
      <H3>{stage.label}（{items.length}）</H3>
      {items.length === 0 ? <Text tone="tertiary">—</Text> : items.map((t: any) => <TaskCard task={t} />)}
    </Stack>
  );
}

export default function BoardCanvas() {
  const recent = changelog.slice(0, 10);
  return (
    <Stack gap={24}>
      <H1>开发看板</H1>
      <Grid columns={4} gap={16}>
        {STAGES.map((s: any) => <StageColumn stage={s} />)}
      </Grid>
      <H2>最近变更</H2>
      <Table
        headers={["时间", "编号", "变更", "触发者"]}
        rows={recent.map((c: any) => [
          c.time.slice(0, 16).replace("T", " "),
          \`#\${c.taskId}\`,
          c.description,
          c.actor,
        ])}
        columnAlign={["left", "left", "left", "left"]}
      />
    </Stack>
  );
}
`;

mkdirSync(canvasDir, { recursive: true });
writeFileSync(canvasFile, canvasCode, "utf8");
console.log(`Canvas generated: ${canvasFile}`);
console.log(`Tasks: ${tasks.length}, Changelog entries: ${changelog.length}`);
