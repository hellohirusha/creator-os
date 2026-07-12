import {
  ApolloClient,
  InMemoryCache,
  createHttpLink,
  from,
  ServerError,
} from "@apollo/client";
import { setContext } from "@apollo/client/link/context";
import { onError } from "@apollo/client/link/error";

// ── HTTP Link — points to Go backend GraphQL endpoint ────────
const httpLink = createHttpLink({
  uri: process.env.REACT_APP_GRAPHQL_URL || "http://localhost:8080/query",
});

// ── Auth Link — adds JWT to every request ────────────────────
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem("access_token");
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    },
  };
});

// ── Error Link — auto-refresh token on 401 ───────────────────
const errorLink = onError(({ error, operation, forward }) => {
  if (ServerError.is(error) && error.statusCode === 401) {
    // Token expired — attempt refresh
    const refreshToken = localStorage.getItem("refresh_token");
    if (!refreshToken) {
      // No refresh token — send to login
      localStorage.clear();
      window.location.href = "/login";
      return;
    }

    // Refresh the access token
    fetch(`${process.env.REACT_APP_API_URL}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: refreshToken }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.access_token) {
          localStorage.setItem("access_token", data.access_token);
          // Retry the failed operation
          return forward(operation);
        } else {
          localStorage.clear();
          window.location.href = "/login";
        }
      });
  }
});

// ── Apollo Client ─────────────────────────────────────────────
export const apolloClient = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      Product: {
        // Products are uniquely identified by id
        keyFields: ["id"],
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      // Always check network for fresh data,
      // but show cache immediately while loading
      fetchPolicy: "cache-and-network",
    },
  },
});
