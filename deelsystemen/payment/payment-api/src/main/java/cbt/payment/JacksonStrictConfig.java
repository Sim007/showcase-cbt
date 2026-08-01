package cbt.payment;

import com.fasterxml.jackson.databind.cfg.CoercionAction;
import com.fasterxml.jackson.databind.cfg.CoercionInputShape;
import com.fasterxml.jackson.databind.type.LogicalType;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Het contract zegt `type: string`. Jackson maakt daar standaard het beste van: een
 * boolean of een getal wordt stilzwijgend een string, en dan neemt Payment een verzoek aan
 * dat volgens de spec ongeldig is.
 *
 * Gevonden door de contractverificatie met `{"orderId": false}`, niet door een eigen test —
 * niemand verzint dat verzoek zelf.
 */
@Configuration
public class JacksonStrictConfig {

    @Bean
    Jackson2ObjectMapperBuilderCustomizer strikteTypes() {
        return builder -> builder.postConfigurer(mapper -> mapper
                .coercionConfigFor(LogicalType.Textual)
                .setCoercion(CoercionInputShape.Boolean, CoercionAction.Fail)
                .setCoercion(CoercionInputShape.Integer, CoercionAction.Fail)
                .setCoercion(CoercionInputShape.Float, CoercionAction.Fail));
    }
}
