package cbt.order;

public record OrderResponse(String orderId, String status, String paymentId) {
}
