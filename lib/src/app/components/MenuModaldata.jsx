// Inside src/components/MenuModal.jsx
const sendToOrder = async () => {
  const token = localStorage.getItem("token");
  
  const payload = {
    tableId: table._id,
    customerPhone: "9999999999", // You can add a prompt for this
    items: cart, // Items from your cart state
    totalAmount: cart.reduce((sum, item) => sum + (item.price * item.qty), 0)
  };

  const res = await fetch(`${apiConfig?.BASE_URL}/api/new-pos/order`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });

  if (res.ok) {
    alert("Order Sent to Kitchen!");
    close();
  }
};