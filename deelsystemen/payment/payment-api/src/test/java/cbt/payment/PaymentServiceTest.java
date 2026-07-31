package cbt.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/**
 * De norm ligt hier in de test. Dit is wat het schema niet dekt: dat een bedrag groter dan
 * nul moet zijn en dat de valutacode moet bestaan.
 */
@Tag("unit")
class PaymentServiceTest {

    private final PaymentRepository repository = mock(PaymentRepository.class);
    private final PaymentService service = new PaymentService(repository);

    PaymentServiceTest() {
        when(repository.save(any(PaymentEntity.class))).thenAnswer(aanroep -> aanroep.getArgument(0));
    }

    @Test
    void bedrag_van_nul_is_een_contractschending() {
        assertThatThrownBy(() -> service.create(verzoek("0.00", "EUR")))
                .isInstanceOf(PaymentRuleException.class)
                .hasFieldOrPropertyWithValue("code", "INVALID_AMOUNT");
    }

    @Test
    void negatief_bedrag_is_een_contractschending() {
        assertThatThrownBy(() -> service.create(verzoek("-1.00", "EUR")))
                .isInstanceOf(PaymentRuleException.class)
                .hasFieldOrPropertyWithValue("code", "INVALID_AMOUNT");
    }

    @Test
    void onbekende_valutacode_is_een_contractschending() {
        assertThatThrownBy(() -> service.create(verzoek("10.00", "XYZ")))
                .isInstanceOf(PaymentRuleException.class)
                .hasFieldOrPropertyWithValue("code", "UNKNOWN_CURRENCY");
    }

    @Test
    void bedrag_boven_de_drempel_wordt_afgewezen_maar_is_geen_fout() {
        assertThat(service.create(verzoek("500.01", "EUR")).getStatus()).isEqualTo("DECLINED");
    }

    @Test
    void bedrag_op_de_drempel_wordt_geaccepteerd() {
        assertThat(service.create(verzoek("500.00", "EUR")).getStatus()).isEqualTo("ACCEPTED");
    }

    @Test
    void identificatie_loopt_op_en_hangt_niet_af_van_toeval() {
        assertThat(service.create(verzoek("10.00", "EUR")).getPaymentId()).isEqualTo("pay-000001");
        assertThat(service.create(verzoek("10.00", "EUR")).getPaymentId()).isEqualTo("pay-000002");
    }

    private static PaymentRequest verzoek(String bedrag, String valuta) {
        return new PaymentRequest("ord-10231", new BigDecimal(bedrag), valuta);
    }
}
