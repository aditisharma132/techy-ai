import { auth } from "@clerk/nextjs/server"
import { runs } from "@trigger.dev/sdk/v3"
import { prisma } from "@/lib/prisma"
import type { NextRequest } from "next/server"

export async function GET(
  _request: NextRequest,
  ctx: { params: Promise<{ runId: string }> }
) {
  const { userId } = await auth()
  if (!userId) return Response.json({ error: "Unauthorized" }, { status: 401 })

  const { runId } = await ctx.params

  const taskRun = await prisma.taskRun.findUnique({ where: { runId } })
  if (!taskRun || taskRun.userId !== userId) {
    return Response.json({ error: "Not found" }, { status: 404 })
  }

  const run = await runs.retrieve(runId)

  return Response.json({ status: run.status, output: run.output })
}
