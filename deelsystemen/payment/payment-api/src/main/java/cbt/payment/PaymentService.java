package cbt.payment;

import java.math.BigDecimal;
import java.util.Set;
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

    /**
     * Gelijk aan de maximum uit het contract. Zonder deze grens neemt Payment een bedrag
     * aan dat hij niet kan opslaan, en dat werd een 500 op een verzoek dat volgens de spec
     * geldig was — gevonden door de contractverificatie, niet door een eigen test.
     */
    static final BigDecimal MAX_BEDRAG = new BigDecimal("999999999.99");

    /** Gelijk aan de enum uit het contract. */
    static final Set<String> VALUTA = Set.of("EUR", "USD", "GBP");

    private final PaymentRepository repository;
    private final AtomicLong teller = new AtomicLong();

    public PaymentService(PaymentRepository repository) {
        this.repository = repository;
    }

    public PaymentEntity create(PaymentRequest verzoek) {
        // Het contract zegt required en type: string. JSON-null voldoet aan het eerste en
        // niet aan het tweede — en zonder deze controle lift hij mee tot in de response,
        // die daarmee zijn eigen schema schendt.
        if (verzoek.orderId() == null) {
            throw new PaymentRuleException("INVALID_REQUEST", "orderId must be a string");
        }
        if (verzoek.amount() == null || verzoek.amount().signum() <= 0) {
            throw new PaymentRuleException("INVALID_AMOUNT", "amount must be greater than zero");
        }
        if (verzoek.amount().compareTo(MAX_BEDRAG) > 0) {
            throw new PaymentRuleException("INVALID_AMOUNT", "amount exceeds the maximum of " + MAX_BEDRAG);
        }
        if (!toegestaneValuta(verzoek.currency())) {
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

    /**
     * Precies de enum uit het contract, niet ISO 4217 uit de JDK. Zou Payment meer
     * accepteren dan hij belooft, dan is de enum in de spec een onwaarheid over wat er
     * gebeurt — en een consumer die op de spec afgaat, weet minder dan hij denkt.
     *
     * Dat deze lijst met de hand gelijk moet blijven aan de spec, is precies waarvoor de
     * drift-check uit 1.4 bestaat.
     */
    private static boolean toegestaneValuta(String code) {
        // De null-check staat er niet voor de sier: Set.of levert een onveranderlijke set
        // die bij contains(null) een NullPointerException gooit. Dat werd een 500 op een
        // verzoek met currency: null.
        return code != null && VALUTA.contains(code);
    }
}
