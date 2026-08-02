package cbt.order.contract;

import static org.assertj.core.api.Assertions.assertThat;

import com.atlassian.oai.validator.OpenApiInteractionValidator;
import com.atlassian.oai.validator.model.SimpleRequest;
import com.atlassian.oai.validator.report.ValidationReport;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/**
 * De consumerkant van de contractverificatie, in beide richtingen.
 *
 * <ol>
 *   <li><b>Wat Order verstuurt voldoet aan de spec.</b> Dat is de richting die een
 *       integratietest met een zelfbedachte mock niet dekt: die mock accepteert immers
 *       precies wat de schrijver had bedacht. Hier komt de norm uit het register.</li>
 *   <li><b>Wat Order doet met de responses uit de spec klopt.</b> ACCEPTED wordt
 *       CONFIRMED, DECLINED wordt CANCELLED.</li>
 * </ol>
 *
 * Draait tegen een gedeployde CI-omgeving: Order met de stub ernaast, en Payment nergens.
 * Wat Order daadwerkelijk verstuurde, komt uit het request journal van de stub — niet uit
 * een verwachting die deze test zelf opschrijft.
 */
@Tag("contract")
class PaymentApiConsumerContractTest {

    private static final String ORDER_URL =
            System.getProperty("contract.base-url", "http://localhost:8082");

    /** De stub speelt de buur; zijn admin-API vertelt wat hij binnenkreeg. */
    private static final String STUB_ADMIN =
            System.getProperty("contract.stub-admin", "http://localhost:8081/__admin");

    private static final String SPEC =
            System.getProperty("contract.spec", "../../../build/contracts/payment-api-1.0.0.yaml");

    private final OpenApiInteractionValidator validator =
            OpenApiInteractionValidator.createFor(SPEC).build();

    private final HttpClient client = HttpClient.newHttpClient();
    private final ObjectMapper mapper = new ObjectMapper();

    @BeforeEach
    void journaalLeeg() throws Exception {
        client.send(HttpRequest.newBuilder(URI.create(STUB_ADMIN + "/requests"))
                .DELETE().build(), HttpResponse.BodyHandlers.discarding());
    }

    // --- richting 1: wat Order verstuurt --------------------------------------------

    @Test
    void wat_order_verstuurt_voldoet_aan_de_spec() throws Exception {
        bestel("49.95", "EUR");
        bestel("600.00", "USD");
        bestel("0.01", "GBP");

        List<String> verstuurd = verzondenNaarPayment();
        assertThat(verstuurd).hasSize(3);

        for (String body : verstuurd) {
            ValidationReport rapport = validator.validateRequest(
                    SimpleRequest.Builder.post("/v1/payments")
                            .withContentType("application/json")
                            .withBody(body)
                            .build());

            assertThat(rapport.hasErrors())
                    .as("Order verstuurde %s: %s", body, rapport)
                    .isFalse();
        }
    }

    // --- richting 2: wat Order met de responses doet ----------------------------------

    @Test
    void geaccepteerde_betaling_wordt_een_bevestigde_bestelling() throws Exception {
        assertThat(bestel("49.95", "EUR")).contains("\"status\":\"CONFIRMED\"");
    }

    @Test
    void afgewezen_betaling_wordt_een_geannuleerde_bestelling() throws Exception {
        // De stub geeft DECLINED terug boven 500,00 — een scenario-mapping, want die
        // scheidslijn is semantiek en volgt niet uit de spec.
        assertThat(bestel("600.00", "EUR")).contains("\"status\":\"CANCELLED\"");
    }

    @Test
    void de_betaling_wordt_op_de_bestelling_vastgelegd() throws Exception {
        assertThat(bestel("49.95", "EUR")).contains("\"paymentId\":");
    }

    // --- hulp ------------------------------------------------------------------------

    private String bestel(String bedrag, String valuta) throws IOException, InterruptedException {
        HttpResponse<String> antwoord = client.send(
                HttpRequest.newBuilder(URI.create(ORDER_URL + "/orders"))
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(
                                "{\"amount\":%s,\"currency\":\"%s\"}".formatted(bedrag, valuta)))
                        .build(),
                HttpResponse.BodyHandlers.ofString());

        assertThat(antwoord.statusCode()).isEqualTo(201);
        return antwoord.body();
    }

    /** De bodies die de stub daadwerkelijk van Order heeft ontvangen. */
    private List<String> verzondenNaarPayment() throws IOException, InterruptedException {
        HttpResponse<String> journaal = client.send(
                HttpRequest.newBuilder(URI.create(STUB_ADMIN + "/requests")).GET().build(),
                HttpResponse.BodyHandlers.ofString());

        List<String> bodies = new ArrayList<>();
        for (JsonNode item : mapper.readTree(journaal.body()).path("requests")) {
            JsonNode verzoek = item.path("request");
            if ("POST".equals(verzoek.path("method").asText())
                    && verzoek.path("url").asText().startsWith("/v1/payments")) {
                bodies.add(verzoek.path("body").asText());
            }
        }
        return bodies;
    }
}
