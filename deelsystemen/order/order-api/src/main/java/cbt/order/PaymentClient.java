package cbt.order;

import java.math.BigDecimal;

/**
 * De grens naar Payment, vanaf de kant van de consumer. Het contract dat hier geldt is de
 * gepubliceerde spec van payment-api, niet iets wat Order zelf bedenkt.
 */
public interface PaymentClient {

    PaymentView create(String orderId, BigDecimal amount, String currency);

    /** Het Payment-schema uit het contract, voor zover Order het gebruikt. */
    record PaymentView(String paymentId, String orderId, String status) {
    }
}
