package cbt.order;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;

@Entity
@Table(name = "bestelling")
public class OrderEntity {

    @Id
    private String orderId;
    private BigDecimal amount;
    private String currency;
    private String status;
    private String paymentId;

    protected OrderEntity() {
        // voor JPA
    }

    OrderEntity(String orderId, BigDecimal amount, String currency, String status, String paymentId) {
        this.orderId = orderId;
        this.amount = amount;
        this.currency = currency;
        this.status = status;
        this.paymentId = paymentId;
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

    public String getPaymentId() {
        return paymentId;
    }
}
