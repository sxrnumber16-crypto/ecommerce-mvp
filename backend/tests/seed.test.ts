import { PrismaClient } from "@prisma/client";
test("seed creates 6 categories", async () => {
  const prisma = new PrismaClient();
  expect(await prisma.category.count()).toBeGreaterThanOrEqual(6);
});
