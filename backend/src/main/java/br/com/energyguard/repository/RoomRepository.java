package br.com.energyguard.repository;

import br.com.energyguard.domain.Room;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface RoomRepository extends JpaRepository<Room, UUID> {

    boolean existsByName(String name);

    boolean existsByNameAndIdNot(String name, UUID id);

    boolean existsByDeviceId(String deviceId);

    boolean existsByDeviceIdAndIdNot(String deviceId, UUID id);

    Optional<Room> findByDeviceId(String deviceId);
}
