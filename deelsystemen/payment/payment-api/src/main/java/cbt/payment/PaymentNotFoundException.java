package cbt.payment;

public class PaymentNotFoundException extends RuntimeException {

    public PaymentNotFoundException(String paymentId) {
        super("no payment with id " + paymentId);
    }
}
