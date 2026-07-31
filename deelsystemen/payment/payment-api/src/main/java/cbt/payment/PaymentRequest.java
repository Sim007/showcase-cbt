package cbt.payment;

import java.math.BigDecimal;

/** Requestbody van POST /v1/payments, zoals in het contract. */
public record PaymentRequest(String orderId, BigDecimal amount, String currency) {
}
