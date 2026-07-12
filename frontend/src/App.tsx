import { Routes, Route } from "react-router-dom";
import { Signup } from "./pages/auth/Signup";
import { ProductsPage } from "./pages/admin/Products";
import { NewProductPage } from "./pages/admin/NewProduct";
import { OrdersPage } from "./pages/admin/Orders";
import { StorefrontPage } from "./pages/store/Storefront";
import { ProductDetailPage } from "./pages/store/ProductDetail";
import { CartPage } from "./pages/store/Cart";
import { OrderSuccessPage } from "./pages/store/OrderSuccess";

function App() {
  return (
    <Routes>
      <Route path="/signup" element={<Signup />} />

      {/* Admin (store owner) */}
      <Route path="/admin/products" element={<ProductsPage />} />
      <Route path="/admin/products/new" element={<NewProductPage />} />
      <Route path="/admin/orders" element={<OrdersPage />} />

      {/* Storefront (shoppers) */}
      <Route path="/store" element={<StorefrontPage />} />
      <Route
        path="/store/:subdomain/products/:slug"
        element={<ProductDetailPage />}
      />
      <Route path="/cart" element={<CartPage />} />
      <Route path="/order/success" element={<OrderSuccessPage />} />
    </Routes>
  );
}

export default App;
