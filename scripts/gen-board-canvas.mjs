// gen-board-canvas.mjs — 从 specs/board/*.json 聚合生成 board.canvas.tsx
// 用法：cd d:\自助编程\实时配置自动化\dataexchange_portal_agent; node scripts/gen-board-canvas.mjs
// 多 agent 并行：每个 agent 只改自己的 specs/board/NNN-功能名.json，不碰别人的
// 交互：点击任务卡片的"查看历史"按钮，下方变更记录联动过滤为该任务历史
// 记录粒度：每次 agent 操作都追加一条 changelog（type 用具体活动，非抽象阶段切换）

import { readFileSync, writeFileSync, readdirSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const boardDir = join(process.cwd(), "specs", "board");
const canvasDir = join(homedir(), ".cursor", "projects", "d", "canvases");
const canvasFile = join(canvasDir, "board.canvas.tsx");

const stages = JSON.parse(readFileSync(join(boardDir, "_stages.json"), "utf8"));
const activityTypes = JSON.parse(readFileSync(join(boardDir, "_activity-types.json"), "utf8"));

const taskFiles = readdirSync(boardDir).filter(f => f.endsWith(".json") && !f.startsWith("_"));
const tasks = taskFiles.map(f => JSON.parse(readFileSync(join(boardDir, f), "utf8")));

const changelog = tasks
  .flatMap(t => (t.changelog || []).map(c => ({ ...c, taskId: t.id })))
  .sort((a, b) => b.time.localeCompare(a.time));

const stagesJson = JSON.stringify(stages);
const activityTypesJson = JSON.stringify(activityTypes);
const tasksJson = JSON.stringify(tasks.map(t => ({
  id: t.id, name: t.name, stage: t.stage, role: t.role,
  progress: t.progress, updatedAt: t.updatedAt, keyChanges: t.keyChanges,
})));
const changelogJson = JSON.stringify(changelog);

const canvasCode = `import { Card, CardHeader, CardBody, Grid, Row, Stack, Spacer, H1, H2, H3, Text, Pill, Stat, Button, Table, Divider, UsageBar, useHostTheme, useState } from "cursor/canvas";

const STAGES = ${stagesJson};
const ACTIVITY_TYPES = ${activityTypesJson};
const tasks = ${tasksJson};
const changelog = ${changelogJson};

function stageLabel(s: string) { return STAGES.find((x: any) => x.key === s)?.label ?? s; }
function stageColor(s: string): any {
  const m: Record<string, string> = { designer: "blue", builder: "yellow", reviewer: "purple", done: "green" };
  return m[s] ?? "gray";
}
function activityTone(type: string): any {
  return ACTIVITY_TYPES.find((x: any) => x.key === type)?.tone ?? "neutral";
}

function TaskCard({ task, selected, onSelect }: { task: any; selected: boolean; onSelect: (id: string) => void }) {
  const theme = useHostTheme();
  const cardStyle = selected ? { borderColor: theme.accent.primary, borderWidth: 2 } : undefined;
  return (
    <Card style={cardStyle}>
      <CardHeader trailing={<Pill size="sm" active>{task.progress}%</Pill>}>
        {task.name}
      </CardHeader>
      <CardBody>
        <Stack gap={10}>
          <Text size="small" tone="tertiary">#{task.id} · {stageLabel(task.stage)} · {task.role}</Text>
          <UsageBar
            segments={[{ id: "progress", value: task.progress, color: stageColor(task.stage) }]}
            total={100}
            topLeftLabel={task.progress < 100 ? "进行中" : "已完成"}
          />
          <Divider />
          <Text size="small" tone="secondary">{task.keyChanges[0] ?? "暂无变更"}</Text>
          <Button variant={selected ? "primary" : "ghost"} onClick={() => onSelect(task.id)}>
            {selected ? "✓ 已选中，下方看它的历史" : "查看此任务历史 →"}
          </Button>
        </Stack>
      </CardBody>
    </Card>
  );
}

function StageColumn({ stage, selectedId, onSelect }: { stage: any; selectedId: string | null; onSelect: (id: string) => void }) {
  const items = tasks.filter((t: any) => t.stage === stage.key);
  return (
    <Stack gap={10}>
      <Row align="center" gap={8}>
        <H3>{stage.label}</H3>
        <Pill size="sm" active={false}>{items.length}</Pill>
      </Row>
      {items.length === 0
        ? <Text tone="tertiary" size="small">— 暂无 —</Text>
        : items.map((t: any) => (
            <TaskCard key={t.id} task={t} selected={selectedId === t.id} onSelect={onSelect} />
          ))
      }
    </Stack>
  );
}

export default function BoardCanvas() {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const counts = {
    total: tasks.length,
    designer: tasks.filter((t: any) => t.stage === "designer").length,
    builder: tasks.filter((t: any) => t.stage === "builder").length,
    reviewer: tasks.filter((t: any) => t.stage === "reviewer").length,
    done: tasks.filter((t: any) => t.stage === "done").length,
  };

  const selectedTask = selectedId ? tasks.find((t: any) => t.id === selectedId) : null;
  const filtered = selectedId ? changelog.filter((c: any) => c.taskId === selectedId) : changelog;

  return (
    <Stack gap={24}>
      <H1>开发看板</H1>

      <Row gap={24}>
        <Stat value={counts.total} label="总任务" />
        <Stat value={counts.designer} label="设计中" tone="info" />
        <Stat value={counts.builder} label="开发中" tone="warning" />
        <Stat value={counts.reviewer} label="审查中" tone="info" />
        <Stat value={counts.done} label="已完成" tone="success" />
      </Row>

      <Grid columns={4} gap={16}>
        {STAGES.map((s: any) => (
          <StageColumn key={s.key} stage={s} selectedId={selectedId} onSelect={setSelectedId} />
        ))}
      </Grid>

      <Stack gap={8}>
        <Row align="center">
          <H2>{selectedTask ? \`#\${selectedTask.id} \${selectedTask.name} · 历史变更\` : "变更记录（全量）"}</H2>
          <Spacer />
          {selectedTask && (
            <Button variant="ghost" onClick={() => setSelectedId(null)}>← 显示全部</Button>
          )}
        </Row>
        <Text size="small" tone="tertiary">
          {selectedTask
            ? \`共 \${filtered.length} 条操作记录，按时间倒序\`
            : \`共 \${changelog.length} 条操作记录，按时间倒序。点击上方任务卡片可查看单任务历史\`}
        </Text>
        <Table
          headers={["时间", "编号", "活动", "操作内容", "触发者"]}
          rows={filtered.map((c: any) => [
            c.time.slice(0, 16).replace("T", " "),
            \`#\${c.taskId}\`,
            c.type,
            c.description,
            c.actor,
          ])}
          columnAlign={["left", "left", "left", "left", "left"]}
          rowTone={filtered.map((c: any) => activityTone(c.type))}
          emptyMessage={selectedTask ? "该任务暂无操作记录" : "暂无操作记录"}
        />
      </Stack>
    </Stack>
  );
}
`;

mkdirSync(canvasDir, { recursive: true });
writeFileSync(canvasFile, canvasCode, "utf8");
console.log(`Canvas generated: ${canvasFile}`);
console.log(`Tasks: ${tasks.length}, Changelog entries: ${changelog.length}`);
