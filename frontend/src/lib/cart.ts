import { create } from "zustand";

export interface CartItem {
  variantId: string;
  productId: string;
  productName: string;
  variantTitle: string;
  price: number;
  quantity: number;
  imageUrl?: string;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (variantId: string) => void;
  updateQuantity: (variantId: string, quantity: number) => void;
  clearCart: () => void;
  totalItems: () => number;
  totalPrice: () => number;
}

export const useCart = create<CartStore>((set, get) => ({
  items: JSON.parse(localStorage.getItem("cart") ?? "[]"),

  addItem: (newItem) => {
    const items = get().items;
    const existing = items.find((i) => i.variantId === newItem.variantId);

    let updated: CartItem[];
    if (existing) {
      // Increment quantity if already in cart
      updated = items.map((i) =>
        i.variantId === newItem.variantId
          ? { ...i, quantity: i.quantity + newItem.quantity }
          : i,
      );
    } else {
      updated = [...items, newItem];
    }

    localStorage.setItem("cart", JSON.stringify(updated));
    set({ items: updated });
  },

  removeItem: (variantId) => {
    const updated = get().items.filter((i) => i.variantId !== variantId);
    localStorage.setItem("cart", JSON.stringify(updated));
    set({ items: updated });
  },

  updateQuantity: (variantId, quantity) => {
    if (quantity <= 0) {
      get().removeItem(variantId);
      return;
    }
    const updated = get().items.map((i) =>
      i.variantId === variantId ? { ...i, quantity } : i,
    );
    localStorage.setItem("cart", JSON.stringify(updated));
    set({ items: updated });
  },

  clearCart: () => {
    localStorage.removeItem("cart");
    set({ items: [] });
  },

  totalItems: () => get().items.reduce((sum, i) => sum + i.quantity, 0),
  totalPrice: () =>
    get().items.reduce((sum, i) => sum + i.price * i.quantity, 0),
}));
