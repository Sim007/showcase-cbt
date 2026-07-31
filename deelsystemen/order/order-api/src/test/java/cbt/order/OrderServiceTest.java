package cbt.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/** De vertaling van betaalstatus naar bestelstatus. De norm ligt in de test. */
@Tag("unit")
class OrderServiceTest {

    private final OrderRepository repository = mock(OrderRepository.class);
    private final PaymentClient paymentClient = mock(PaymentClient.class);
    private final OrderService service = new OrderService(repository, paymentClient);

    OrderServiceTest() {
        when(repository.save(any(OrderEntity.class))).thenAnswer(aanroep -> aanroep.getArgument(0));
    }

    @Test
    void geaccepteerde_betaling_bevestigt_de_bestelling() {
        betaalStatus("ACCEPTED");
        assertThat(service.place(bestelling("49.95")).getStatus()).isEqualTo("CONFIRMED");
    }

    @Test
    void afgewezen_betaling_annuleert_de_bestelling() {
        betaalStatus("DECLINED");
        assertThat(service.place(bestelling("600.00")).getStatus()).isEqualTo("CANCELLED");
    }

    @Test
    void de_betaling_wordt_op_de_bestelling_vastgelegd() {
        betaalStatus("ACCEPTED");
        assertThat(service.place(bestelling("49.95")).getPaymentId()).isEqualTo("pay-000001");
    }

    @Test
    void identificatie_loopt_op_en_hangt_niet_af_van_toeval() {
        betaalStatus("ACCEPTED");
        assertThat(service.place(bestelling("10.00")).getOrderId()).isEqualTo("ord-00001");
        assertThat(service.place(bestelling("10.00")).getOrderId()).isEqualTo("ord-00002");
    }

    private void betaalStatus(String status) {
        when(paymentClient.create(anyString(), any(BigDecimal.class), eq("EUR")))
                .thenAnswer(aanroep -> new PaymentClient.PaymentView(
                        "pay-000001", aanroep.getArgument(0), status));
    }

    private static OrderRequest bestelling(String bedrag) {
        return new OrderRequest(new BigDecimal(bedrag), "EUR");
    }
}
