package cbt.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * HTTP, serialisatie en de eigen database erbij.
 *
 * De buur staat hier als test-double op de client, niet als HTTP-stub. De stub wordt
 * gegenereerd uit de spec uit het register en bestaat pas in stap 3; een handgeschreven
 * mapping nu zou precies zijn wat 1.6 van het document verbiedt — een test die zijn eigen
 * mapping definieert.
 */
@Tag("integratie")
@SpringBootTest
@AutoConfigureMockMvc
class OrderIntegratieTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private OrderRepository repository;

    @MockitoBean
    private PaymentClient paymentClient;

    @Test
    void bestelling_wordt_bevestigd_en_is_daarna_op_te_vragen() throws Exception {
        betaalStatus("ACCEPTED");

        String antwoord = mockMvc.perform(post("/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount":49.95,"currency":"EUR"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("CONFIRMED"))
                .andReturn().getResponse().getContentAsString();

        String orderId = antwoord.replaceAll(".*\"orderId\":\"([^\"]+)\".*", "$1");
        assertThat(repository.findById(orderId)).isPresent();

        mockMvc.perform(get("/orders/{id}", orderId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderId").value(orderId));
    }

    @Test
    void afgewezen_betaling_annuleert_de_bestelling() throws Exception {
        betaalStatus("DECLINED");

        mockMvc.perform(post("/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount":600.00,"currency":"EUR"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void onbekende_bestelling_levert_een_404_op() throws Exception {
        mockMvc.perform(get("/orders/ord-00000"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ORDER_NOT_FOUND"));
    }

    /**
     * Een onbekend pad is een 404 en geen 500. Het vangnet voor onverwachte fouten mag de
     * status die Spring al heeft bepaald niet overschrijven.
     */
    @Test
    void onbekend_pad_levert_een_404_op() throws Exception {
        mockMvc.perform(get("/actuator/env"))
                .andExpect(status().isNotFound());
    }

    private void betaalStatus(String status) {
        when(paymentClient.create(anyString(), any(BigDecimal.class), anyString()))
                .thenAnswer(aanroep -> new PaymentClient.PaymentView(
                        "pay-000001", aanroep.getArgument(0), status));
    }
}
