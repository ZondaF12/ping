import { createContext, useContext, type ReactNode } from "react";
import { usePingRegistrationImpl } from "@/hooks/usePingRegistration";

type PingRegistrationValue = ReturnType<typeof usePingRegistrationImpl>;

const PingRegistrationContext = createContext<PingRegistrationValue | null>(
    null,
);

export function PingRegistrationProvider({
    children,
}: {
    children: ReactNode;
}) {
    const value = usePingRegistrationImpl();
    return (
        <PingRegistrationContext.Provider value={value}>
            {children}
        </PingRegistrationContext.Provider>
    );
}

export function usePingRegistration(): PingRegistrationValue {
    const v = useContext(PingRegistrationContext);
    if (!v) {
        throw new Error(
            "usePingRegistration must be used within PingRegistrationProvider",
        );
    }
    return v;
}
