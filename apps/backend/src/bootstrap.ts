import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/errors';
import { Env } from './config/env';

export async function createApp(env: Env): Promise<INestApplication> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule.forRoot(env), {
    logger: env.NODE_ENV === 'test' ? ['error'] : ['log', 'warn', 'error'],
    bodyParser: false,
  });
  // Only trust X-Forwarded-For from the configured number of proxy hops (rate limits key on the client IP).
  app.set('trust proxy', env.TRUST_PROXY_HOPS > 0 ? env.TRUST_PROXY_HOPS : false);
  app.useBodyParser('json', { limit: env.BODY_LIMIT });
  app.useBodyParser('urlencoded', { limit: env.BODY_LIMIT, extended: false });
  app.use(helmet());
  app.enableCors({ origin: env.CORS_ORIGINS === '*' ? true : env.CORS_ORIGINS.split(',').map((s) => s.trim()) });
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.useGlobalFilters(new AllExceptionsFilter());
  app.enableShutdownHooks();

  if (env.NODE_ENV !== 'production') {
    const doc = SwaggerModule.createDocument(
      app,
      new DocumentBuilder()
        .setTitle('Zaad Pharmacies API')
        .setDescription(`Customer app + admin API. ERP adapter: ${env.ERP_ADAPTER}.`)
        .setVersion('1.0')
        .addBearerAuth()
        .build(),
    );
    SwaggerModule.setup('docs', app, doc);
  }
  return app;
}
