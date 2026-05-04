import apiConfig from "./apiConfig";

export const shiftOrderTable = async (orderId, newTableNumber, token) => {
  try {
    const res = await fetch(
      `${apiConfig?.BASE_URL}/api/pos/orders/${orderId}/shift`,
      {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ newTableNumber }),
      }
    );

    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "Shift failed");
    }

    return data;

  } catch (err) {
    console.error("SHIFT_API_ERROR:", err);
    throw err;
  }
};