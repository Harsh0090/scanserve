import apiConfig from "./apiConfig";
export const cancelOrder = async (orderId, token) => {
  try {
    const res = await fetch(
      `${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/cancel`,
      {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }
    );

    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "Cancel failed");
    }

    return data;

  } catch (err) {
    console.error("CANCEL_API_ERROR:", err);
    throw err;
  }
};