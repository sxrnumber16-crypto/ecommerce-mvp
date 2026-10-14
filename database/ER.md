# Database ER (Ecommerce MVP)

Provider: **SQLite** locally (`backend/prisma/schema.prisma`), **MySQL** in
production (`backend/prisma/schema.mysql.prisma`). The two schemas are
identical except `datasource db.provider` (`sqlite` vs `mysql`); all models,
relations and indexes are the same. SQLite is a local-dev convenience only —
concurrent-checkout behaviour under load is verified by logic tests, not by
production-grade concurrency.

## Tables

### User
| Column | Type | Notes |
|---|---|---|
| id | Int PK autoincrement | |
| email | String unique | login identity |
| passwordHash | String | argon2id hash, never plaintext |
| role | String default `"customer"` | `"admin"` set only via seed / admin:create |
| createdAt / updatedAt | DateTime | |

Relations: 1–1 `CustomerProfile`, 1–N `Address`, 1–N `Order`, 1–N `RefreshSession`.

### CustomerProfile
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| userId | Int unique FK → User.id ON DELETE Cascade | |
| fullName / phone | String? | |

### Address
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| userId | Int FK → User.id ON DELETE Cascade | owner |
| label | String? | e.g. `home` |
| line1 | String | required |
| city | String | required |
| postal | String? | |
| phone | String | required |
| isDefault | Boolean default false | only one default per user (app-level switch) |

Relations: 1–N `Order` (address kept as order snapshot reference).

### Category
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| name / slug | String unique | slug used for filtering |
| icon | String? | Material icon name |
| sort | Int default 0 | list ordering |

Relations: 1–N `Product`.

### Product
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| categoryId | Int FK → Category.id | RESTRICT (no cascade) |
| name / slug(unique) / description / priceBdt(Int) / stock(Int) / imageUrl? | | price in BDT minor unit (integer Taka) |
| isActive | Boolean default true | soft-delete flag; public catalog filters `isActive: true` |
| createdAt / updatedAt | DateTime | |

Indexes: `@@index([categoryId])`, `@@index([isActive])`.

### Order
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| userId | Int FK → User.id | buyer |
| addressId | Int FK → Address.id | delivery address |
| subtotal / deliveryFee / total | Int | **server-calculated** (`total = subtotal + deliveryFee`) |
| status | String default `"pending"` | `pending\|confirmed\|shipped\|delivered\|cancelled` |
| idempotencyKey | String unique | client-supplied, min 8 chars |
| createdAt / updatedAt | DateTime | |

Indexes: `@@index([userId])`, `@@index([status])`.
Relations: 1–N `OrderItem`, 1–1 `Payment`.

### OrderItem
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| orderId | Int FK → Order.id ON DELETE Cascade | |
| productId | Int FK → Product.id | price snapshot kept in row |
| name | String | product name snapshot |
| unitPrice / qty / lineTotal | Int | `lineTotal = unitPrice * qty` |

Indexes: `@@index([orderId])`, `@@index([productId])`.

### Payment
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| orderId | Int unique FK → Order.id ON DELETE Cascade | |
| method | String default `"COD"` | COD-only for MVP |
| status | String default `"unpaid"` | COD orders stay `unpaid` until cash collected |
| amount | Int | equals order total |
| providerRef | String? | unused for COD |

### RefreshSession
| Column | Type | Notes |
|---|---|---|
| id | Int PK | |
| userId | Int FK → User.id ON DELETE Cascade | |
| tokenHash | String unique | SHA-256 of refresh JWT (raw token never stored) |
| expiresAt | DateTime | 30 days |
| revokedAt | DateTime? | set on rotation / logout |

Indexes: `@@index([userId])`.

## Diagram (text)

```
User 1──1 CustomerProfile
User 1──N Address 1──N Order
User 1──N Order 1──N OrderItem N──1 Product N──1 Category
Order 1──1 Payment
User 1──N RefreshSession
```
