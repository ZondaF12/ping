import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { json } from 'express';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  app.enableCors({ origin: true });
  app.use(json({ strict: false }));
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}
void bootstrap();
