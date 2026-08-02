package cbt.payment.contract;

import static org.assertj.core.api.Assertions.assertThat;

import com.atlassian.oai.validator.OpenApiInteractionValidator;
import com.atlassian.oai.validator.model.Request;
import com.atlassian.oai.validator.model.SimpleResponse;
import com.atlassian.oai.validator.report.ValidationReport;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/**
 * De geschreven kant van de contractverificatie: elke aanroep staat hier met de hand, en
 * de gepubliceerde spec bepaalt of het antwoord klopt. De norm ligt dus buiten de test.
 *
 * Draait tegen een gedeployd deelsysteem, niet tegen de code — een contract is een belofte
 * van een draaiend systeem, en configuratie en serialisatie horen daarbij.
 *
 * Naast deze test staat de gegenereerde variant (Schemathesis, zie ci/verify-contract.sh).
 * De showcase houdt ze allebei omdat het verschil de moeite van het zien waard is: wat je
 * zelf opschrijft, dekt wat je zelf bedenkt.
 */
@Tag("contract")
class PaymentApiProviderContractTest {

    private static final String BASIS_URL =
            System.getProperty("contract.base-url", "http://localhost:8081");

    /** De spec komt uit het register, neergezet door ci/get-contract.sh. */
    private static final String SPEC =
            System.getProperty("contract.spec", "../../../build/contracts/payment-api-1.0.0.yaml");

    private final OpenApiInteractionValidator validator =
            OpenApiInteractionValidator.createFor(SPEC).build();

    private final HttpClient client = HttpClient.newHttpClient();

    @Test
    void betaling_aanmaken_levert_een_geldige_201() throws Exception {
        HttpResponse<String> antwoord = post("""
                {"orderId":"ord-10231","amount":49.95,"currency":"EUR"}""");

        assertThat(antwoord.statusCode()).isEqualTo(201);
        volgtDeSpec("/v1/payments", Request.Method.POST, antwoord);
        assertThat(antwoord.body()).contains("\"status\":\"ACCEPTED\"");
    }

    @Test
    void bedrag_boven_de_drempel_is_geen_fout_maar_een_afwijzing() throws Exception {
        HttpResponse<String> antwoord = post("""
                {"orderId":"ord-10232","amount":600.00,"currency":"EUR"}""");

        assertThat(antwoord.statusCode()).isEqualTo(201);
        volgtDeSpec("/v1/payments", Request.Method.POST, antwoord);
        assertThat(antwoord.body()).contains("\"status\":\"DECLINED\"");
    }

    @Test
    void ongeldig_bedrag_levert_een_geldige_400() throws Exception {
        HttpResponse<String> antwoord = post("""
                {"orderId":"ord-10233","amount":0,"currency":"EUR"}""");

        assertThat(antwoord.statusCode()).isEqualTo(400);
        volgtDeSpec("/v1/payments", Request.Method.POST, antwoord);
    }

    @Test
    void onbekende_valuta_levert_een_geldige_400() throws Exception {
        HttpResponse<String> antwoord = post("""
                {"orderId":"ord-10234","amount":10.00,"currency":"AAA"}""");

        assertThat(antwoord.statusCode()).isEqualTo(400);
        volgtDeSpec("/v1/payments", Request.Method.POST, antwoord);
    }

    @Test
    void betaling_opvragen_levert_een_geldige_200() throws Exception {
        String aangemaakt = post("""
                {"orderId":"ord-10235","amount":12.50,"currency":"EUR"}""").body();
        String paymentId = aangemaakt.replaceAll(".*\"paymentId\":\"([^\"]+)\".*", "$1");

        HttpResponse<String> antwoord = get("/v1/payments/" + paymentId);

        assertThat(antwoord.statusCode()).isEqualTo(200);
        volgtDeSpec("/v1/payments/{paymentId}", Request.Method.GET, antwoord);
    }

    @Test
    void onbekende_betaling_levert_een_geldige_404() throws Exception {
        HttpResponse<String> antwoord = get("/v1/payments/pay-000000");

        assertThat(antwoord.statusCode()).isEqualTo(404);
        volgtDeSpec("/v1/payments/{paymentId}", Request.Method.GET, antwoord);
    }

    /** Hier ligt de norm: niet in de test maar in de spec uit het register. */
    private void volgtDeSpec(String pad, Request.Method methode, HttpResponse<String> antwoord) {
        ValidationReport rapport = validator.validateResponse(pad, methode,
                SimpleResponse.Builder.status(antwoord.statusCode())
                        .withContentType("application/json")
                        .withBody(antwoord.body())
                        .build());

        assertThat(rapport.hasErrors())
                .as("%s %s levert %d: %s", methode, pad, antwoord.statusCode(), rapport)
                .isFalse();
    }

    private HttpResponse<String> post(String body) throws IOException, InterruptedException {
        return client.send(HttpRequest.newBuilder(URI.create(BASIS_URL + "/v1/payments"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build(), HttpResponse.BodyHandlers.ofString());
    }

    private HttpResponse<String> get(String pad) throws IOException, InterruptedException {
        return client.send(HttpRequest.newBuilder(URI.create(BASIS_URL + pad)).GET().build(),
                HttpResponse.BodyHandlers.ofString());
    }
}
