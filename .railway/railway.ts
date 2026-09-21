import { bucket, defineRailway, postgres, project, service, volume } from "railway/iac";

export default defineRailway(() => {
  const Postgres = postgres("Postgres", { region: "sfo" });
  Postgres.networking = { privateNetworkEndpoint: "postgres" };
  const PostgresK1st = postgres("Postgres-k1st", { region: "sfo" });
  PostgresK1st.networking = { privateNetworkEndpoint: "postgres-k1st" };
  const postgresVolume66bY = volume("postgres-volume-66bY", { alerts: { usage: { "100": {}, "80": {}, "95": {} } }, allowOnlineResize: true, region: "sfo", sizeMB: 500 });
  const postgresVolume = volume("postgres-volume", { alerts: { usage: { "100": {}, "80": {}, "95": {} } }, allowOnlineResize: true, region: "sfo", sizeMB: 500 });
  const fitcalgaryPrivate = bucket("fitcalgary-private", { region: "sjc" });

  return project("fitcalgary-production", {
    resources: [Postgres, PostgresK1st, postgresVolume66bY, postgresVolume, fitcalgaryPrivate],
  });
});
