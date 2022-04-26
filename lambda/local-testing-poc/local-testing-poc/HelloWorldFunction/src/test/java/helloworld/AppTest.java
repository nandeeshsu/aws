package helloworld;

import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.Bucket;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mockito;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.localstack.LocalStackContainer;
import org.testcontainers.images.builder.ImageFromDockerfile;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;
import uk.org.webcompere.systemstubs.environment.EnvironmentVariables;
import uk.org.webcompere.systemstubs.jupiter.SystemStub;
import uk.org.webcompere.systemstubs.jupiter.SystemStubsExtension;

import static org.testcontainers.containers.localstack.LocalStackContainer.Service.S3;

import java.io.File;
import java.io.IOException;
import java.util.List;

@Testcontainers
@ExtendWith(SystemStubsExtension.class)
public class AppTest {

  private static final String BUCKET_NAME = "test-bucket";

  private static final int PORT = 22;
  private static final String USER = "user";
  private static final String PASSWORD = "password";
  private static final String FILE_NAME = "test.txt";
  private static final String REMOTE_PATH = "/upload/";

 // @SystemStub
  //private static EnvironmentVariables environmentVariables;

  @TempDir
  private static File directory;

  //ftp/ec2 testcontainer
  //https://overflowed.dev/blog/sftp-testing-junit-testcontainers-atmoz-sftp/
  private static final GenericContainer sftp = new GenericContainer(
          new ImageFromDockerfile()
                  .withDockerfileFromBuilder(builder ->
                          builder
                                  .from("atmoz/sftp:latest")
                                  .run("mkdir -p /home/" + USER + "/upload; chmod -R 007 /home/" + USER)
                                  .build()))
          .withExposedPorts(PORT)
          .withCommand(USER + ":" + PASSWORD + ":1001:::upload");

  @Container
  static LocalStackContainer localStack =
          new LocalStackContainer(DockerImageName.parse("localstack/localstack:0.14.2"))
                  .withServices(S3);

  @BeforeAll
  static void beforeAll() throws IOException, InterruptedException {
    localStack.execInContainer("awslocal", "s3", "mb", "s3://" + BUCKET_NAME);

    //environmentVariables.set("cloud.aws.s3.endpoint", localStack.getEndpointOverride(S3));
    //environmentVariables.set("cloud.aws.credentials.access-key", localStack.getAccessKey());
    //environmentVariables.set("cloud.aws.credentials.secret-key", localStack.getSecretKey());

    File sftpTestFile = new File(directory.getAbsolutePath() + "/" + FILE_NAME);
    sftpTestFile.createNewFile();

    //copy your files to the sftp
    sftp.withCopyFileToContainer(MountableFile.forHostPath(sftpTestFile.getPath()), "/home/" + USER + "/upload/" + sftpTestFile.getName());
    sftp.start();
  }

  @AfterAll
  static void afterAll() {
    sftp.stop();
  }

//  @DynamicPropertySource
//  static void overrideConfiguration(DynamicPropertyRegistry registry) {
//
//    registry.add("cloud.aws.s3.endpoint", () -> localStack.getEndpointOverride(S3));
//    registry.add("cloud.aws.credentials.access-key", localStack::getAccessKey);
//    registry.add("cloud.aws.credentials.secret-key", localStack::getSecretKey);
//  }

  @Test
  public void successfulResponse() {
    AmazonS3 s3 = AmazonS3ClientBuilder
            .standard()
            //.withRegion("us-east-1")
            //.withForceGlobalBucketAccessEnabled(true)
            .withEndpointConfiguration(localStack.getEndpointConfiguration(S3))
            .withCredentials(localStack.getDefaultCredentialsProvider())
            .build();

    List<Bucket> buckets = s3.listBuckets();
    for(Bucket bucket : buckets) {
      System.out.println("listing buckets from test::" + bucket.getName());
    }

    App app = new App();
    App spy = Mockito.spy(app);
    Mockito.doReturn(s3).when(spy).getAmazonS3();

    APIGatewayProxyResponseEvent result = spy.handleRequest(null, null);
    assertEquals(200, result.getStatusCode().intValue());
    assertEquals("application/json", result.getHeaders().get("Content-Type"));
    String content = result.getBody();
    assertNotNull(content);
    assertTrue(content.contains("\"message\""));
    assertTrue(content.contains("\"hello world\""));
    assertTrue(content.contains("\"location\""));
  }
}
