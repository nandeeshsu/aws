package nandu.jitte.demoecs;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
@Slf4j
public class DemoCommandLineRunner implements CommandLineRunner {
    /**
     * Callback used to run the bean.
     *
     * @param args incoming main method arguments
     * @throws Exception on error
     */
    @Override
    public void run(String... args) throws Exception {
        log.info("Welcome to Spring Boot Command Line Runner with CPU Cores {}", Runtime.getRuntime().availableProcessors());

        Map<String, String> env = System.getenv();

        log.info("ENVIRONMENT VARIABLES:: {}", env);
    }
}
