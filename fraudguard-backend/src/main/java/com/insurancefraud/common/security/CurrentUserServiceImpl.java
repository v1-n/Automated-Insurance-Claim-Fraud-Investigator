package com.insurancefraud.common.security;
import com.insurancefraud.entity.User;
import com.insurancefraud.common.exception.AccountDeletedException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class CurrentUserServiceImpl
        implements CurrentUserService {

    @Override
    public User getCurrentUser() {
        Authentication authentication =
                SecurityContextHolder
                        .getContext()
                        .getAuthentication();

        if (authentication == null || !authentication.isAuthenticated()) {
            throw new InsufficientAuthenticationException(
                    "User not authenticated"
            );
        }

        Object principal =  authentication.getPrincipal();

        if (!(principal instanceof User)) {
            throw new InsufficientAuthenticationException(
                    "Invalid authentication principal"
            );
        }

        log.info("Current user: {}", ((User) principal).getEmail());
        return (User) principal;
    }

    @Override
    public User getCurrentActiveUser() {
        User user = getCurrentUser();
        if (user.isDeleted()) {
            throw new AccountDeletedException(
                    "Account already deleted"
            );
        }
        log.info("Active user: {}", user.getEmail());
        return user;
    }
}