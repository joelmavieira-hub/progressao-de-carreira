import {
  AlertCircle,
  LayoutDashboard,
  Target,
  TrendingUp,
  type LucideIcon,
} from "lucide-react";
import {
  NavLink,
  useLocation,
  useNavigate,
} from "react-router-dom";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { CareerDashboard } from "@/features/career-progression/components/dashboard/CareerDashboard";
import { CareerProgressionBoard } from "@/features/career-progression/components/progression/CareerProgressionBoard";
import { useCareerProgressionData } from "@/features/career-progression/hooks/useCareerProgressionData";

const Index = () => {
  const location = useLocation();
  const navigate = useNavigate();

  const tab =
    location.pathname === "/progressao"
      ? "progression"
      : "dashboard";

  const locationState = location.state as {
    focus?: "meta3" | "promoted";
  } | null;

  const {
    perfis,
    resultados,
    resumo,
    perfisOperacionais,
    resultadosOperacionais,
    perfisOperacionaisComHistorico,
    isLoading,
    isFetching,
    error,
    refetch,
    lastUpdatedAt,
  } = useCareerProgressionData();

  const navigateToProgression = (
    focus?: "meta3" | "promoted",
  ) =>
    navigate("/progressao", {
      state: focus ? { focus } : undefined,
    });

  /**
   * Conta todos os SDRs e Closers inativos da base histórica.
   *
   * Pessoas com squad ou jornada "Saiu" continuam entrando
   * nesta contagem, embora não apareçam no escopo operacional.
   *
   * Outras funções, como Parcerias, não são contabilizadas.
   */
  const historicalInactiveCount = perfis.filter(
    (perfil) => {
      const position = perfil.posicao_atual
        ?.trim()
        .toLocaleLowerCase("pt-BR");

      const isCareerPosition =
        position === "sdr" ||
        position === "closer";

      return !perfil.ativo && isCareerPosition;
    },
  ).length;

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-purple-950/30 bg-gradient-to-br from-violet-950 via-purple-900 to-violet-700 text-white">
        <div className="container mx-auto max-w-7xl px-6 py-10 text-center">
          <div className="mx-auto flex max-w-3xl flex-col items-center space-y-4">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-3 py-1 text-white">
              <Target
                aria-hidden="true"
                className="h-3.5 w-3.5"
              />

              <span className="text-[11px] font-bold uppercase tracking-wider">
                Plataforma de gestão profissional
              </span>
            </div>

            <h1 className="font-display text-4xl font-extrabold tracking-tight md:text-5xl">
              Progressão de Carreira
            </h1>

            <p className="text-sm leading-6 text-purple-100 md:text-base">
              Dados oficiais de senioridade, evolução e promoções
              dos colaboradores
            </p>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-[1680px] px-4 py-6 sm:px-6 lg:px-8">
        <div className="space-y-6">
          <nav
            aria-label="Navegação principal"
            role="tablist"
            className="flex w-full border-b"
          >
            <NavigationTab
              to="/"
              label="Dashboard"
              active={tab === "dashboard"}
              icon={LayoutDashboard}
            />

            <NavigationTab
              to="/progressao"
              label="Progressão"
              active={tab === "progression"}
              icon={TrendingUp}
            />
          </nav>

          {isLoading ? (
            <LoadingState mode={tab} />
          ) : error ? (
            <ErrorState
              isFetching={isFetching}
              onRetry={() => void refetch()}
            />
          ) : !resumo || perfis.length === 0 ? (
            <EmptyState />
          ) : (
            <>
              {tab === "dashboard" ? (
                <section
                  role="tabpanel"
                  aria-labelledby="tab-dashboard"
                >
                  <CareerDashboard
                    perfis={perfisOperacionais}
                    resultados={resultadosOperacionais}
                    perfisComHistorico={
                      perfisOperacionaisComHistorico
                    }
                    historicalProfileCount={perfis.length}
                    historicalResultCount={resultados.length}
                    historicalInactiveCount={
                      historicalInactiveCount
                    }
                    isFetching={isFetching}
                    lastUpdatedAt={lastUpdatedAt}
                    onRefresh={() => void refetch()}
                    onNavigate={navigateToProgression}
                  />
                </section>
              ) : (
                <section
                  role="tabpanel"
                  aria-labelledby="tab-progression"
                >
                  <CareerProgressionBoard
                    perfis={perfisOperacionais}
                    resultados={resultadosOperacionais}
                    perfisComHistorico={
                      perfisOperacionaisComHistorico
                    }
                    focus={locationState?.focus}
                  />
                </section>
              )}
            </>
          )}
        </div>

        <footer className="mt-16 border-t pt-6 text-center text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
          TOCA A BUZINA, META BATIDA É A CW QUE DOMINA!
        </footer>
      </main>
    </div>
  );
};

function NavigationTab({
  to,
  label,
  active,
  icon: Icon,
}: {
  to: string;
  label: string;
  active: boolean;
  icon: LucideIcon;
}) {
  return (
    <NavLink
      id={`tab-${to === "/" ? "dashboard" : "progression"}`}
      to={to}
      role="tab"
      aria-selected={active}
      className={`flex items-center gap-2 border-b-2 px-6 py-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 ${
        active
          ? "border-primary text-primary"
          : "border-transparent text-muted-foreground hover:text-foreground"
      }`}
    >
      <Icon
        aria-hidden="true"
        className="h-4 w-4"
      />

      {label}
    </NavLink>
  );
}

function LoadingState({
  mode,
}: {
  mode: string;
}) {
  return (
    <div
      role="status"
      aria-label="Carregando dados"
      className="space-y-5"
    >
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from(
          { length: 4 },
          (_, index) => (
            <Skeleton
              key={index}
              className="h-36 rounded-2xl"
            />
          ),
        )}
      </div>

      {mode === "progression" ? (
        <div className="flex gap-4 overflow-hidden">
          {Array.from(
            { length: 5 },
            (_, index) => (
              <Skeleton
                key={index}
                className="h-[520px] min-w-72 rounded-2xl"
              />
            ),
          )}
        </div>
      ) : (
        <div className="grid gap-5 xl:grid-cols-2">
          <Skeleton className="h-72 rounded-2xl" />
          <Skeleton className="h-72 rounded-2xl" />
          <Skeleton className="h-80 rounded-2xl xl:col-span-2" />
        </div>
      )}
    </div>
  );
}

function ErrorState({
  isFetching,
  onRetry,
}: {
  isFetching: boolean;
  onRetry: () => void;
}) {
  return (
    <Card
      data-testid="database-summary-card"
      className="mx-auto max-w-xl"
    >
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <AlertCircle
            aria-hidden="true"
            className="h-5 w-5 text-destructive"
          />

          Banco de Dados
        </CardTitle>
      </CardHeader>

      <CardContent className="space-y-4 text-center">
        <div>
          <h2 className="font-semibold">
            Não foi possível carregar os dados
          </h2>

          <p className="text-sm text-muted-foreground">
            Tente atualizar a leitura do Supabase.
          </p>
        </div>

        <Button
          aria-label="Atualizar dados"
          onClick={onRetry}
          disabled={isFetching}
        >
          {isFetching
            ? "Atualizando"
            : "Atualizar"}
        </Button>
      </CardContent>
    </Card>
  );
}

function EmptyState() {
  return (
    <Card>
      <CardContent className="p-10 text-center">
        <h2 className="font-semibold">
          O banco ainda não possui perfis
        </h2>

        <p className="text-sm text-muted-foreground">
          Os dados aparecerão aqui após a próxima sincronização
          autorizada.
        </p>
      </CardContent>
    </Card>
  );
}

export default Index;