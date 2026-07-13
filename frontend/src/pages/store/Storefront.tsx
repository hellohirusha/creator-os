import { gql } from "@apollo/client";
import { useQuery } from "@apollo/client/react";
import { Link } from "react-router-dom";
import { ShoppingCart, Search } from "lucide-react";
import { useTenant } from "../../hooks/useTenant";
import { useCart } from "../../lib/cart";

const GET_STORE_PRODUCTS = gql`
  query GetStoreProducts($tenantId: UUID!) {
    products(tenantId: $tenantId, status: "active") {
      id
      name
      slug
      basePrice
      comparePrice
      shortDesc
      images {
        url
        position
      }
      variants {
        isInStock
        stockQuantity
      }
      tags
    }
  }
`;

export function StorefrontPage() {
  const { tenant, subdomain, loading: tenantLoading } = useTenant();
  const { totalItems } = useCart();

  const { data, loading: productsLoading } = useQuery<{ products: any[] }>(
    GET_STORE_PRODUCTS,
    {
      variables: { tenantId: tenant?.id },
      skip: !tenant?.id,
    },
  );

  if (tenantLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-green-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!tenant) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900">Store not found</h1>
          <p className="text-gray-500 mt-2">
            No store exists at <strong>{subdomain}</strong>
          </p>
        </div>
      </div>
    );
  }

  const products = data?.products ?? [];
  const loading = productsLoading;

  return (
    <div className="min-h-screen bg-white">
      {/* Storefront header */}
      <header className="sticky top-0 z-10 bg-white border-b border-gray-100 px-4 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <h1 className="text-xl font-bold text-gray-900">{tenant.name}</h1>
          <div className="flex items-center gap-3">
            <button className="p-2 text-gray-500 hover:text-gray-900 transition-colors">
              <Search size={20} />
            </button>
            <Link
              to="/cart"
              className="flex items-center gap-2 px-4 py-2 bg-gray-900 text-white
                               rounded-lg text-sm font-medium hover:bg-gray-800 transition-colors"
            >
              <ShoppingCart size={16} />
              <span>Cart ({totalItems()})</span>
            </Link>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-8">
        {/* Hero section */}
        <div className="mb-10 text-center">
          <h2 className="text-4xl font-bold text-gray-900 mb-3">
            Welcome to {tenant.name}
          </h2>
          <p className="text-gray-500 max-w-xl mx-auto">
            Browse our collection below
          </p>
        </div>

        {/* Product grid — skeleton while loading */}
        {loading ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {[...Array(8)].map((_, i) => (
              <div key={i} className="animate-pulse">
                <div className="aspect-square bg-gray-100 rounded-xl mb-3" />
                <div className="h-4 bg-gray-100 rounded w-3/4 mb-2" />
                <div className="h-4 bg-gray-100 rounded w-1/4" />
              </div>
            ))}
          </div>
        ) : products.length === 0 ? (
          <div className="text-center py-20">
            <p className="text-gray-400 text-lg">No products available yet</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {products.map((product: any) => {
              const primaryImage = product.images.find(
                (img: any) => img.position === 0,
              );
              const inStock = product.variants.some((v: any) => v.isInStock);
              const hasDiscount =
                product.comparePrice &&
                product.comparePrice > product.basePrice;
              const discountPercent = hasDiscount
                ? Math.round(
                    ((product.comparePrice - product.basePrice) /
                      product.comparePrice) *
                      100,
                  )
                : 0;

              return (
                <Link
                  key={product.id}
                  to={`/store/${subdomain}/products/${product.slug}`}
                  className="group"
                >
                  {/* Image */}
                  <div className="aspect-square bg-gray-50 rounded-xl overflow-hidden relative mb-3">
                    {primaryImage ? (
                      <img
                        src={primaryImage.url}
                        alt={product.name}
                        className="w-full h-full object-cover group-hover:scale-105
                                   transition-transform duration-300"
                        loading="lazy"
                      />
                    ) : (
                      <div className="w-full h-full bg-gradient-to-br from-gray-100 to-gray-200" />
                    )}

                    {/* Discount badge */}
                    {hasDiscount && (
                      <div
                        className="absolute top-2 left-2 bg-red-500 text-white
                                      text-xs font-bold px-2 py-0.5 rounded-full"
                      >
                        -{discountPercent}%
                      </div>
                    )}

                    {/* Out of stock overlay */}
                    {!inStock && (
                      <div className="absolute inset-0 bg-black/40 flex items-center justify-center rounded-xl">
                        <span className="bg-white text-gray-900 text-xs font-medium px-3 py-1 rounded-full">
                          Out of stock
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Info */}
                  <div>
                    <h3
                      className="text-sm font-medium text-gray-900 group-hover:text-green-600
                                   transition-colors line-clamp-2"
                    >
                      {product.name}
                    </h3>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="text-sm font-bold text-gray-900">
                        ${product.basePrice.toFixed(2)}
                      </span>
                      {hasDiscount && (
                        <span className="text-xs text-gray-400 line-through">
                          ${product.comparePrice.toFixed(2)}
                        </span>
                      )}
                    </div>
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}
