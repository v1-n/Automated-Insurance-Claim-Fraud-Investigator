package com.insurancefraud.auth.service.impl;

import com.insurancefraud.auth.dto.*;
import com.insurancefraud.auth.repository.RefreshTokenRepo;
import com.insurancefraud.common.exception.*;
import com.insurancefraud.entity.RefreshToken;
import com.insurancefraud.entity.Role;
import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.RoleCode;
import com.insurancefraud.enums.UserStatus;
import com.insurancefraud.repository.*;
import com.insurancefraud.auth.service.AuthService;
import com.insurancefraud.common.security.CurrentUserService;
import com.insurancefraud.service.EmailService;
import com.insurancefraud.service.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.modelmapper.ModelMapper;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
@Transactional
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final UserRepo userRepo;
    private final TenantRepo tenantRepo;
    private final RoleRepo roleRepo;
    private final ModelMapper mapper;
    private final PasswordEncoder encoder;
    private final JwtService jwtService;
    private final EmailService emailService;
    private final RefreshTokenRepo refreshTokenRepo;
    private final AuthenticationManager authManager;
    private final CurrentUserService currentUserService;

    // Register User and send Verification email
    @Override
    public void registerUser(RegisterRequestDto requestDto) {

        if (userRepo.existsByEmail(requestDto.getEmail())) {
            throw new UserAlreadyExistsException(
                    "A user with email " + requestDto.getEmail() + " already exists."
            );
        }
        Tenant tenant = tenantRepo.findByTenantCode(requestDto.getTenantCode())
                .orElseThrow(() ->
                        new TenantNotFoundException(
                                "No tenant exists with code: " + requestDto.getTenantCode()
                        )
                );
        Role userRole = roleRepo.findByRoleCode(RoleCode.USER)
                .orElseThrow(() ->
                        new RoleNotFoundException("Default USER role not found.")
                );

        User newUser = mapper.map(requestDto, User.class);
        newUser.setPasswordHash(
                encoder.encode(requestDto.getPassword())
        );



        newUser.setStatus(UserStatus.PENDING);
        newUser.setTenant(tenant);
        newUser.setRole(userRole);
        newUser.setEmailVerifiedAt(null);
        User savedUser = userRepo.save(newUser);
        log.info("User registered email {} ",savedUser.getEmail());

        String token = jwtService.generateEmailVerificationToken(savedUser);
        emailService.sendVerificationEmail(savedUser.getEmail(), token);


    }

    // Verify User Email
    @Override
    public void verifyEmail(String token) {
        Long userId = jwtService.extractUserId(token);
        User user = userRepo.findById(userId).orElseThrow(()->
                new UsernameNotFoundException("User not found..."));

        if(user.getEmailVerifiedAt() !=null){
            throw  new EmailAlreadyVerifiedException("Already Verified");
        }
        user.setEmailVerifiedAt(Instant.now());
        user.setStatus(UserStatus.ACTIVE);
        userRepo.save(user);
    }

    // login user
    @Override
    @Transactional
    public LoginResponseDto authenticateUser(LoginRequestDto loginDto) {

        User user = userRepo
                .findByEmailWithRoleAndTenant(loginDto.getEmail())
                .orElseThrow(() ->
                        new BadCredentialsException(
                                "Invalid email or password"
                        ));

        if (user.isDeleted()) {
            throw new AccountDeletedException("Account deleted");
        }

        authManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        loginDto.getEmail(),
                        loginDto.getPassword()
                )
        );

        if (user.getEmailVerifiedAt() == null) {
            throw new EmailNotVerifiedException(
                    "Email not verified"
            );
        }

        String accessToken =
                jwtService.generateToken(user);

        String refreshTokenString =
                jwtService.generateRefreshToken(user);

        saveRefreshTokenToDB(user, refreshTokenString);

        // MANUAL DTO MAPPING
        UserResponseDto userDto = new UserResponseDto();

        userDto.setUserId(user.getUserId());
        userDto.setFullName(user.getFullName());
        userDto.setEmail(user.getEmail());
        userDto.setAvatarUrl(user.getAvatarUrl());

        userDto.setRole(
                user.getRole().getRoleCode().name()
        );

        userDto.setTenantCode(
                user.getTenant().getTenantCode()
        );

        userDto.setStatus(
                user.getStatus().name()
        );

        LoginResponseDto response =
                new LoginResponseDto();

        response.setAccessToken(accessToken);
        response.setRefreshToken(refreshTokenString);
        response.setUser(userDto);

        log.info("User logged in: {}", userDto.getEmail());
        return response;
    }

    //logout user
    @Override
    @Transactional
    public void logout(LogoutRequestDto logoutDto) {
        User currentUser = currentUserService.getCurrentActiveUser();
        RefreshToken token = refreshTokenRepo
                .findByToken(logoutDto.getRefreshToken())
                .orElseThrow(() ->
                        new TokenNotFoundException("Invalid Refresh Token")
                );

        // CHECK TOKEN OWNER
        if (!token.getUser().getUserId().equals(currentUser.getUserId())) {
            throw new RuntimeException(
                    "You are not allowed to revoke this token"
            );
        }
        // CHECK REVOKED
        if (token.isRevoked()) {
            throw new TokenAlreadyRevokedException(
                    "Token already revoked"
            );
        }
        // CHECK EXPIRY
        if (token.getExpiresAt().isBefore(Instant.now())) {
            throw new TokenExpiredException(
                    "Refresh token expired"
            );
        }

        token.setRevoked(true);
        refreshTokenRepo.save(token);
        log.info("User logged out successfully: {}",  currentUser.getEmail() );
    }

    //resend email verification
    @Override
    public void resendVerification(String email) {

        User user = userRepo.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        if (user.getEmailVerifiedAt() != null) {
            throw new EmailAlreadyVerifiedException("Already verified");
        }
        String token = jwtService.generateEmailVerificationToken(user);
        emailService.sendVerificationEmail(email, token);
        log.info("ResendEmailVerification  email :{}",email);
    }

    //delete user account
    @Override
    @Transactional
    public void delete(DeleteRequestDto deleteDto) {

        User user = currentUserService.getCurrentActiveUser();
  
        // CHECK PASSWORD
        if (!encoder.matches(deleteDto.getPassword(), user.getPasswordHash())) {
            throw new BadCredentialsException("Invalid password");
        }
        // REVOKE ALL REFRESH TOKENS
        List<RefreshToken> allTokens = refreshTokenRepo.findByUser(user);
        for (RefreshToken token : allTokens) {
            token.setRevoked(true);
        }
        refreshTokenRepo.saveAll(allTokens);
        // SOFT DELETE
        user.setEmail(
                "deleted_" + user.getUserId() + "_" + user.getEmail()
        );
        user.setDeleted(true);
        user.setDeletedAt(Instant.now());
        user.setStatus(UserStatus.DELETED);
        user.setUpdatedAt(Instant.now());
        userRepo.save(user);
        log.info("Account deleted for user {}", user.getEmail());
    }

    @Override
    public void forgotPassword(ForgotPasswordRequestDto requestDto) {


        Optional<User> optionalUser =
                userRepo.findByEmail(
                        requestDto.getEmail()
                );

        // ALWAYS RETURN SUCCESS
        if (optionalUser.isEmpty()) {
            log.info("optional user is empty");
            return;
        }

        User user = optionalUser.get();

        if (user.isDeleted()) {
            log.info("user is deleted");
            return;
        }

        String token =  jwtService.generatePasswordResetToken(user);

        emailService.sendPasswordResetEmail(
                user.getEmail(),
                token
        );
        log.info(
                "AUTH_SERVICE : Password reset email sent to {}",
                user.getEmail()
        );
    }

    @Override
    @Transactional
    public void resetPassword(ResetPasswordRequestDto requestDto) {
        Long userId =
                jwtService.extractUserId(
                        requestDto.getToken()
                );
        User user = userRepo.findById(userId)
                .orElseThrow(() ->
                        new UserNotFoundException(
                                "User not found"
                        )
                );
        if (user.isDeleted()) {
            throw new AccountDeletedException(
                    "Account deleted"
            );
        }
        user.setPasswordHash(
                encoder.encode(
                        requestDto.getNewPassword()
                )
        );
        user.setUpdatedAt(Instant.now());
        userRepo.save(user);
        // REVOKE ALL TOKENS
        List<RefreshToken> tokens =
                refreshTokenRepo.findByUser(user);

        for (RefreshToken token : tokens) {
            token.setRevoked(true);
        }
        refreshTokenRepo.saveAll(tokens);
    }

    //Save Refresh Token Into DB
    public void saveRefreshTokenToDB(User user,String refreshTokenString){
        RefreshToken refreshTokenEntity = new RefreshToken();
        refreshTokenEntity.setUser(user);
        refreshTokenEntity.setToken(refreshTokenString);
        refreshTokenEntity.setExpiresAt(Instant.now().plus(java.time.Duration.ofDays(7)));
        refreshTokenRepo.save(refreshTokenEntity);
        log.info("RefreshToken saved to DB for Email : {} ",user.getEmail() );
    }

    @Override
    @Transactional
    public void changePassword(ChangePasswordRequestDto requestDto) {
        User user = currentUserService.getCurrentActiveUser();
        if (user.isDeleted()) {
            throw new AccountDeletedException("Account deleted");
        }
        if (!encoder.matches(requestDto.getOldPassword(), user.getPasswordHash())) {
            throw new BadCredentialsException("Invalid old password");
        }
        user.setPasswordHash(encoder.encode(requestDto.getNewPassword()));
        user.setUpdatedAt(Instant.now());
        userRepo.save(user);

        // Revoke all active refresh tokens to force re-login on other sessions
        List<RefreshToken> tokens = refreshTokenRepo.findByUser(user);
        for (RefreshToken token : tokens) {
            token.setRevoked(true);
        }
        refreshTokenRepo.saveAll(tokens);
        log.info("Password changed successfully for user: {}", user.getEmail());
    }
}
