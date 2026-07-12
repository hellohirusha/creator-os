import { gql } from "@apollo/client";
import { useQuery } from "@apollo/client/react";

const GET_TENANT = gql`
  query GetTenantBySubdomain($subdomain: String!) {
    tenant(subdomain: $subdomain) {
      id
      name
      subdomain
      plan
    }
  }
`;

export function useTenant() {
  // In production: parse subdomain from window.location.hostname
  // In development: read from query param or localStorage
  const hostname = window.location.hostname; // e.g. "teststore.creatorOS.app"
  const parts = hostname.split(".");

  let subdomain = "";
  if (parts.length >= 3) {
    subdomain = parts[0]; // "teststore"
  } else {
    // Development fallback — use URL param
    subdomain =
      new URLSearchParams(window.location.search).get("store") ||
      localStorage.getItem("demo_subdomain") ||
      "";
  }

  const { data, loading, error } = useQuery<{
    tenant?: { id: string; name: string; subdomain: string; plan: string };
  }>(GET_TENANT, {
    variables: { subdomain },
    skip: !subdomain,
  });

  return {
    tenant: data?.tenant,
    subdomain,
    loading,
    error,
  };
}
