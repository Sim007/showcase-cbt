package cbt.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * De laag erboven: HTTP, serialisatie en de eigen database erbij. De norm ligt ook hier in
 * de test — toetsing aan de gepubliceerde spec is een aparte laag en volgt in stap 3.
 */
@Tag("integratie")
@SpringBootTest
@AutoConfigureMockMvc
class PaymentIntegratieTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private PaymentRepository repository;

    @Test
    void betaling_wordt_aangemaakt_en_is_daarna_op_te_vragen() throws Exception {
        String antwoord = mockMvc.perform(post("/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"orderId":"ord-10231","amount":49.95,"currency":"EUR"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.orderId").value("ord-10231"))
                .andExpect(jsonPath("$.status").value("ACCEPTED"))
                .andReturn().getResponse().getContentAsString();

        String paymentId = antwoord.replaceAll(".*\"paymentId\":\"([^\"]+)\".*", "$1");
        assertThat(repository.findById(paymentId)).isPresent();

        mockMvc.perform(get("/v1/payments/{id}", paymentId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paymentId").value(paymentId));
    }

    @Test
    void bedrag_boven_de_drempel_levert_een_afgewezen_betaling_op_en_geen_fout() throws Exception {
        mockMvc.perform(post("/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"orderId":"ord-10232","amount":600.00,"currency":"EUR"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DECLINED"));
    }

    @Test
    void ongeldig_bedrag_levert_het_error_schema_op() throws Exception {
        mockMvc.perform(post("/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"orderId":"ord-10233","amount":0,"currency":"EUR"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_AMOUNT"))
                .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void onbekende_valuta_levert_het_error_schema_op() throws Exception {
        mockMvc.perform(post("/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"orderId":"ord-10234","amount":10.00,"currency":"XYZ"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("UNKNOWN_CURRENCY"));
    }

    @Test
    void onbekende_betaling_levert_een_404_met_het_error_schema_op() throws Exception {
        mockMvc.perform(get("/v1/payments/pay-000000"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("PAYMENT_NOT_FOUND"));
    }

    /** additionalProperties: false uit het contract mag niet stilzwijgend meeliften. */
    @Test
    void niet_gedeclareerd_veld_wordt_geweigerd() throws Exception {
        mockMvc.perform(post("/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"orderId":"ord-10235","amount":10.00,"currency":"EUR","tip":1.00}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    /**
     * Een onbekend pad is een 404 en geen 500. Het vangnet voor onverwachte fouten mag de
     * status die Spring al heeft bepaald niet overschrijven.
     */
    @Test
    void onbekend_pad_levert_een_404_op() throws Exception {
        mockMvc.perform(get("/actuator/env"))
                .andExpect(status().isNotFound());
        mockMvc.perform(get("/v1/betalingen"))
                .andExpect(status().isNotFound());
    }

    /** Een foutresponse bevat nooit een stacktrace of een intern pad. */
    @Test
    void foutresponse_lekt_niets() throws Exception {
        String body = mockMvc.perform(get("/v1/payments/pay-000000"))
                .andReturn().getResponse().getContentAsString();

        assertThat(body).doesNotContain("cbt.payment").doesNotContain("Exception").doesNotContain("/");
    }
}
