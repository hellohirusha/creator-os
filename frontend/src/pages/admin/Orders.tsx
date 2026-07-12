import { gql } from "@apollo/client";
import { useQuery } from "@apollo/client/react";
import { Package, Clock, CheckCircle, Truck } from "lucide-react";

const GET_ORDERS = gql`
  query GetOrders {
    orders {
      id
      status
      total
      customerEmail
      customerName
      items {
        productName
        quantity
        unitPrice
      }
      createdAt
      paidAt
    }
  }
`;

const STATUS_CONFIG: Record<
  string,
  { label: string; color: string; icon: any }
> = {
  pending: {
    label: "Pending",
    color: "bg-yellow-100 text-yellow-700",
    icon: Clock,
  },
  paid: {
    label: "Paid",
    color: "bg-green-100 text-green-700",
    icon: CheckCircle,
  },
  processing: {
    label: "Processing",
    color: "bg-blue-100 text-blue-700",
    icon: Package,
  },
  shipped: {
    label: "Shipped",
    color: "bg-purple-100 text-purple-700",
    icon: Truck,
  },
  delivered: {
    label: "Delivered",
    color: "bg-gray-100 text-gray-700",
    icon: CheckCircle,
  },
  cancelled: {
    label: "Cancelled",
    color: "bg-red-100 text-red-700",
    icon: Clock,
  },
};

export function OrdersPage() {
  const { data, loading } = useQuery<{ orders: any[] }>(GET_ORDERS, {
    pollInterval: 30000, // Refresh every 30s to show new orders
  });

  const orders = data?.orders ?? [];
  const totalRevenue = orders
    .filter((o: any) => o.status !== "cancelled" && o.status !== "pending")
    .reduce((sum: number, o: any) => sum + o.total, 0);

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Orders</h1>
          <p className="text-sm text-gray-500 mt-1">
            {orders.length} orders · ${totalRevenue.toFixed(2)} revenue
          </p>
        </div>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <div
              key={i}
              className="h-20 bg-gray-100 rounded-xl animate-pulse"
            />
          ))}
        </div>
      ) : orders.length === 0 ? (
        <div className="text-center py-16">
          <Package className="mx-auto h-16 w-16 text-gray-200 mb-4" />
          <h3 className="text-lg font-medium text-gray-900">No orders yet</h3>
          <p className="text-gray-500 text-sm mt-1">
            Orders appear here after checkout
          </p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50">
                <th className="text-left px-4 py-3 font-medium text-gray-600">
                  Order
                </th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">
                  Customer
                </th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">
                  Items
                </th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">
                  Total
                </th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">
                  Status
                </th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">
                  Date
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {orders.map((order: any) => {
                const config =
                  STATUS_CONFIG[order.status] ?? STATUS_CONFIG.pending;
                const Icon = config.icon;

                return (
                  <tr
                    key={order.id}
                    className="hover:bg-gray-50 transition-colors"
                  >
                    <td className="px-4 py-3 font-mono text-xs text-gray-400">
                      #{order.id.slice(-8).toUpperCase()}
                    </td>
                    <td className="px-4 py-3 text-gray-700">
                      {order.customerEmail}
                    </td>
                    <td className="px-4 py-3 text-gray-500">
                      {order.items.map((i: any) => i.productName).join(", ")}
                    </td>
                    <td className="px-4 py-3 font-semibold text-gray-900">
                      ${order.total.toFixed(2)}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${config.color}`}
                      >
                        <Icon size={10} />
                        {config.label}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-400 text-xs">
                      {new Date(order.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
