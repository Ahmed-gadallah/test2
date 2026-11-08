import { DynamicModule, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AdminAuthController, AdminGuard } from './admin/admin-auth';
import { AdminController } from './admin/admin.controller';
import { AuditModule } from './audit/audit.service';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { CustomerAuthGuard } from './auth/customer-auth.guard';
import { OtpService } from './auth/otp/otp.service';
import { ENV, Env } from './config/env';
import { CustomerController } from './customer/customer.controller';
import { BalanceCache } from './customer/balance-cache';
import { DbModule } from './db/db.module';
import { DevController } from './dev/dev.controller';
import { ErpModule } from './erp/erp.module';
import { HealthController } from './health.controller';
import { NotificationsController } from './notifications/notifications.controller';
import { NotificationsService } from './notifications/notifications.service';
import { AdminOffersController, OffersController } from './offers/offers.controller';
import { OffersService } from './offers/offers.service';
import { RedemptionController } from './redemption/redemption.controller';
import { RedemptionService } from './redemption/redemption.service';

@Module({})
export class AppModule {
  static forRoot(env: Env): DynamicModule {
    const controllers: DynamicModule['controllers'] = [
      HealthController,
      AuthController,
      CustomerController,
      NotificationsController,
      RedemptionController,
      OffersController,
      AdminAuthController,
      AdminOffersController,
      AdminController,
    ];
    // Dev simulation endpoints exist ONLY with the mock ERP (which production refuses at startup).
    if (env.ERP_ADAPTER === 'mock') controllers.push(DevController);

    return {
      module: AppModule,
      global: true,
      imports: [
        { module: class EnvModule {}, global: true, providers: [{ provide: ENV, useValue: env }], exports: [ENV] },
        DbModule,
        ErpModule,
        AuditModule,
        JwtModule.register({}),
        ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: env.NODE_ENV === 'test' ? 10_000 : 120 }]),
      ],
      controllers,
      providers: [
        { provide: APP_GUARD, useClass: ThrottlerGuard },
        AuthService,
        OtpService,
        CustomerAuthGuard,
        AdminGuard,
        NotificationsService,
        RedemptionService,
        OffersService,
        BalanceCache,
      ],
    };
  }
}
