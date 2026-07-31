package cbt.payment;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.math.BigDecimal;

@Entity
public class PaymentEntity {

    @Id
    private String paymentId;
    private String orderId;
    private BigDecimal amount;
    private String currency;
    private String status;

    protected PaymentEntity() {
        // voor JPA
    }

    PaymentEntity(String paymentId, String orderId, BigDecimal amount, String currency, String status) {
        this.paymentId = paymentId;
        this.orderId = orderId;
        this.amount = amount;
        this.currency = currency;
        this.status = status;
    }

    public String getPaymentId() {
        return paymentId;
    }

    public String getOrderId() {
        return orderId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public String getStatus() {
        return status;
    }
}
