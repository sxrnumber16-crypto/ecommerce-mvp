import { PrismaClient } from "@prisma/client";
import * as argon2 from "argon2";

const prisma = new PrismaClient();

const categories = [
  { name: "Clothing", slug: "clothing", icon: "checkroom", sort: 1 },
  { name: "Electronics", slug: "electronics", icon: "devices", sort: 2 },
  { name: "Home", slug: "home", icon: "home", sort: 3 },
  { name: "Beauty", slug: "beauty", icon: "spa", sort: 4 },
  { name: "Accessories", slug: "accessories", icon: "watch", sort: 5 },
  { name: "Others", slug: "others", icon: "category", sort: 6 },
];

const products = [
  {
    name: "Men's Cotton Panjabi",
    slug: "mens-cotton-panjabi",
    description: "Premium cotton panjabi for everyday and festive wear.",
    priceBdt: 1250,
    stock: 50,
    imageUrl: "https://picsum.photos/seed/panjabi/600/600",
    categorySlug: "clothing",
  },
  {
    name: "Women's Kurti",
    slug: "womens-kurti",
    description: "Comfortable stylish kurti in assorted prints.",
    priceBdt: 1450,
    stock: 40,
    imageUrl: "https://picsum.photos/seed/kurti/600/600",
    categorySlug: "clothing",
  },
  {
    name: "Smartphone X10",
    slug: "smartphone-x10",
    description: "6.5-inch display, 128GB storage, long battery life.",
    priceBdt: 18990,
    stock: 25,
    imageUrl: "https://picsum.photos/seed/smartphone/600/600",
    categorySlug: "electronics",
  },
  {
    name: "Wireless Earbuds",
    slug: "wireless-earbuds",
    description: "Bluetooth earbuds with charging case.",
    priceBdt: 2490,
    stock: 100,
    imageUrl: "https://picsum.photos/seed/earbuds/600/600",
    categorySlug: "electronics",
  },
  {
    name: "Cotton Bedsheet",
    slug: "cotton-bedsheet",
    description: "King-size cotton bedsheet with pillow covers.",
    priceBdt: 1890,
    stock: 60,
    imageUrl: "https://picsum.photos/seed/bedsheet/600/600",
    categorySlug: "home",
  },
  {
    name: "Ceramic Dinner Set",
    slug: "ceramic-dinner-set",
    description: "24-piece ceramic dinner set for family use.",
    priceBdt: 3290,
    stock: 30,
    imageUrl: "https://picsum.photos/seed/dinner-set/600/600",
    categorySlug: "home",
  },
  {
    name: "Herbal Face Wash",
    slug: "herbal-face-wash",
    description: "Gentle herbal face wash for all skin types.",
    priceBdt: 450,
    stock: 200,
    imageUrl: "https://picsum.photos/seed/facewash/600/600",
    categorySlug: "beauty",
  },
  {
    name: "Matte Lipstick Set",
    slug: "matte-lipstick-set",
    description: "Set of 6 long-lasting matte lipsticks.",
    priceBdt: 890,
    stock: 150,
    imageUrl: "https://picsum.photos/seed/lipstick/600/600",
    categorySlug: "beauty",
  },
  {
    name: "Leather Wallet",
    slug: "leather-wallet",
    description: "Genuine leather bifold wallet for men.",
    priceBdt: 790,
    stock: 120,
    imageUrl: "https://picsum.photos/seed/wallet/600/600",
    categorySlug: "accessories",
  },
  {
    name: "Travel Backpack",
    slug: "travel-backpack",
    description: "Water-resistant 35L travel backpack.",
    priceBdt: 1590,
    stock: 80,
    imageUrl: "https://picsum.photos/seed/backpack/600/600",
    categorySlug: "others",
  },
];

async function main() {
  for (const c of categories) {
    await prisma.category.upsert({
      where: { slug: c.slug },
      update: { name: c.name, icon: c.icon, sort: c.sort },
      create: c,
    });
  }

  for (const p of products) {
    const category = await prisma.category.findUniqueOrThrow({
      where: { slug: p.categorySlug },
    });
    const { categorySlug, ...data } = p;
    await prisma.product.upsert({
      where: { slug: data.slug },
      update: { ...data, categoryId: category.id, isActive: true },
      create: { ...data, categoryId: category.id, isActive: true },
    });
  }

  // Demo admin via env (local defaults only; change in prod).
  const adminEmail = process.env.ADMIN_EMAIL ?? "admin@demo.com";
  const adminPassword = process.env.ADMIN_PASSWORD ?? "Demo1234!";
  const passwordHash = await argon2.hash(adminPassword, { type: argon2.argon2id });
  await prisma.user.upsert({
    where: { email: adminEmail },
    update: { passwordHash, role: "admin" },
    create: { email: adminEmail, passwordHash, role: "admin" },
  });

  const counts = {
    categories: await prisma.category.count(),
    products: await prisma.product.count(),
    users: await prisma.user.count(),
  };
  console.log(`Seed done: ${JSON.stringify(counts)} admin=${adminEmail}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
