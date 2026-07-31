package cbt.payment;

/**
 * Een verzoek dat niet aan de specificatie voldoet. Levert een 400 op met het Error-schema.
 * Onderscheiden van een afgewezen betaling: die is een geldig verzoek met een negatieve
 * uitkomst en levert een 201 met status DECLINED op.
 */
public class PaymentRuleException extends RuntimeException {

    private final String code;

    public PaymentRuleException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
