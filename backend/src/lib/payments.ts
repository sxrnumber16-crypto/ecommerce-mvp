export interface CreatePaymentParams {
  orderId: number;
  amount: number;
}

export type PaymentInitResult = { status: "unpaid"; providerRef?: string };
export type DeferredPaymentResult = { status: "configuration_required"; providerRef?: string };

export interface PaymentProvider {
  name: "COD";
  create(params: CreatePaymentParams): PaymentInitResult | Promise<PaymentInitResult>;
}

export class CodProvider implements PaymentProvider {
  readonly name = "COD" as const;

  create(_params: CreatePaymentParams): PaymentInitResult {
    return { status: "unpaid" };
  }
}

export const paymentProviders = new Map<string, PaymentProvider>([["COD", new CodProvider()]]);

export const paymentRegistry: Record<string, PaymentProvider> = {
  COD: new CodProvider(),
};

// bKash/Nagad are NOT wired for checkout (COD-only). These stubs never fake
// success: they require credentials and always report configuration_required.
export function createBkashPayment(_params?: {
  orderId?: number;
  amount?: number;
}): DeferredPaymentResult {
  const user = process.env.BKASH_USERNAME ?? "";
  const pass = process.env.BKASH_PASSWORD ?? "";
  void user;
  void pass;
  return { status: "configuration_required" };
}

export function createNagadPayment(_params?: {
  orderId?: number;
  amount?: number;
}): DeferredPaymentResult {
  const merchant = process.env.NAGAD_MERCHANT_ID ?? "";
  const key = process.env.NAGAD_PRIVATE_KEY ?? "";
  void merchant;
  void key;
  return { status: "configuration_required" };
}
