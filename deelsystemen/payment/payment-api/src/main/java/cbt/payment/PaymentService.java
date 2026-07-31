package cbt.payment;

import java.math.BigDecimal;
import java.util.Currency;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.stereotype.Service;

/**
 * Het gedrag uit 1.2 van docs/showcase-cbt.md. Bewust minimaal en volledig deterministisch:
 * een demo mag niet afhangen van toeval of van de tijd.
 */
@Service
public class PaymentService {

    /** Willekeurig maar vast. Levert twee scenario's op die niet uit de spec volgen. */
    static final BigDecimal DECLINE_DREMPEL = new BigDecimal("500.00");

    private final PaymentRepository repository;
    private final AtomicLong teller = new AtomicLong();

    public PaymentService(PaymentRepository repository) {
        this.repository = repository;
    }

    public PaymentEntity create(PaymentRequest verzoek) {
        if (verzoek.amount() == null || verzoek.amount().signum() <= 0) {
            throw new PaymentRuleException("INVALID_AMOUNT", "amount must be greater than zero");
        }
        if (!bestaandeValuta(verzoek.currency())) {
            throw new PaymentRuleException("UNKNOWN_CURRENCY", "unknown currency " + verzoek.currency());
        }

        // Een afgewezen betaling is een geldig verzoek met een negatieve uitkomst, geen
        // contractschending: 201 met een status, geen 4xx.
        String status = verzoek.amount().compareTo(DECLINE_DREMPEL) > 0 ? "DECLINED" : "ACCEPTED";

        // Geen UUID: een oplopend nummer houdt de demo herhaalbaar.
        String paymentId = "pay-%06d".formatted(teller.incrementAndGet());

        return repository.save(new PaymentEntity(
                paymentId, verzoek.orderId(), verzoek.amount(), verzoek.currency(), status));
    }

    public Optional<PaymentEntity> find(String paymentId) {
        return repository.findById(paymentId);
    }

    /** ISO 4217 uit de JDK, zodat er geen zelfgemaakte lijst is die veroudert. */
    private static boolean bestaandeValuta(String code) {
        if (code == null) {
            return false;
        }
        try {
            Currency.getInstance(code);
            return true;
        } catch (IllegalArgumentException onbekend) {
            return false;
        }
    }
}
