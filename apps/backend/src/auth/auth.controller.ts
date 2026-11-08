import { Body, Controller, HttpCode, Ip, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { LoginDto, MobileDto, RefreshDto, RegisterDto, ResetPasswordDto, SendOtpDto, VerifyOtpDto } from './auth.dto';
import { AuthService } from './auth.service';
import { CurrentCustomer, CustomerAuthGuard, CustomerPrincipal } from './customer-auth.guard';

@ApiTags('auth')
@Controller('auth')
@Throttle({ default: { limit: 10, ttl: 60_000 } })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('check-mobile')
  @HttpCode(200)
  @ApiOperation({ summary: 'Check if a mobile number belongs to an ERP customer who can register' })
  async checkMobile(@Body() dto: MobileDto) {
    return { data: await this.auth.checkMobile(dto.mobile) };
  }

  @Post('send-otp')
  @HttpCode(200)
  @ApiOperation({ summary: 'Send a verification code (WhatsApp preferred, SMS fallback)' })
  async sendOtp(@Body() dto: SendOtpDto, @Ip() ip: string) {
    return { data: await this.auth.sendOtp(dto.mobile, dto.purpose, ip ?? null) };
  }

  @Post('verify-otp')
  @HttpCode(200)
  @ApiOperation({ summary: 'Verify the code and receive a single-use verification token' })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return { data: await this.auth.verifyOtp(dto.mobile, dto.purpose, dto.code) };
  }

  @Post('register')
  @ApiOperation({ summary: 'Create the app account linked to the ERP customer' })
  async register(@Body() dto: RegisterDto) {
    return { data: await this.auth.register(dto) };
  }

  @Post('login')
  @HttpCode(200)
  async login(@Body() dto: LoginDto) {
    return { data: await this.auth.login(dto) };
  }

  @Post('refresh')
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  async refresh(@Body() dto: RefreshDto) {
    return { data: await this.auth.refresh(dto.refreshToken) };
  }

  @Post('logout')
  @HttpCode(200)
  @ApiBearerAuth()
  @UseGuards(CustomerAuthGuard)
  async logout(@CurrentCustomer() c: CustomerPrincipal) {
    await this.auth.logout(c.sessionId);
    return { data: { ok: true } };
  }

  @Post('forgot-password')
  @HttpCode(200)
  @ApiOperation({ summary: 'Alias of send-otp with purpose=reset_password' })
  async forgot(@Body() dto: MobileDto, @Ip() ip: string) {
    return { data: await this.auth.sendOtp(dto.mobile, 'reset_password', ip ?? null) };
  }

  @Post('reset-password')
  @HttpCode(200)
  async reset(@Body() dto: ResetPasswordDto) {
    return { data: await this.auth.resetPassword(dto.verificationToken, dto.password) };
  }
}
