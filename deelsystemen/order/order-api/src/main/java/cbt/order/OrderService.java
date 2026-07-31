package cbt.order;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.stereotype.Service;

/**
 * Order neemt een bestelling aan, roept Payment aan en verwerkt de uitkomst. De vertaling
 * van betaalstatus naar bestelstatus is de enige businessregel hier.
 */
@Service
public class OrderService {

    private final OrderRepository repository;
    private final PaymentClient paymentClient;
    private final AtomicLong teller = new AtomicLong();

    public OrderService(OrderRepository repository, PaymentClient paymentClient) {
        this.repository = repository;
        this.paymentClient = paymentClient;
    }

    public OrderEntity place(OrderRequest verzoek) {
        // Geen UUID: een oplopend nummer houdt de demo herhaalbaar.
        String orderId = "ord-%05d".formatted(teller.incrementAndGet());

        PaymentClient.PaymentView betaling =
                paymentClient.create(orderId, verzoek.amount(), verzoek.currency());

        String status = switch (betaling.status()) {
            case "ACCEPTED" -> "CONFIRMED";
            case "DECLINED" -> "CANCELLED";
            default -> throw new IllegalStateException("onbekende betaalstatus");
        };

        return repository.save(new OrderEntity(
                orderId, verzoek.amount(), verzoek.currency(), status, betaling.paymentId()));
    }

    public Optional<OrderEntity> find(String orderId) {
        return repository.findById(orderId);
    }
}
