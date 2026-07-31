package cbt.payment;

/** Het Payment-schema uit het contract. */
public record PaymentResponse(String paymentId, String orderId, String status) {
}
