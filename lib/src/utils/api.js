import apiConfig from "./apiConfig";
export const placeOrder = async (payload) => {
  const res = await fetch(`${apiConfig?.BASE_URL}/api/public/orders`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  const data = await res.json();
  if (!res.ok) throw new Error(data.message);
  return data;
};
